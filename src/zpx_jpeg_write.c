/* JPEG encoding through libjpeg-turbo's compressor (design §4.2): 8-bit,
 * no SIMD, no arithmetic coding, optimised Huffman tables, progressive on
 * request. libjpeg-turbo reports errors by calling error_exit, which the
 * vendored jerror.c (patched) routes to zpx_int_jpeg_error_exit(): a
 * longjmp back to the setjmp below, inside this function's own frame. */

#include <setjmp.h>
#include <stdio.h>
#include <string.h>

#include "jpeglib.h"

#include "zpx_core.h"
#include "zpx_jpeg.h"

#define OUT_CHUNK 65536

/* A destination manager that hands each full buffer to the sink. A failed
 * sink longjmps like a libjpeg error. */
typedef struct {
  struct jpeg_destination_mgr pub;
  zpx_write_fn write;
  void *closure;
  zpx_jpeg_jmp *jmp;
  int sink_failed;
  JOCTET buf[OUT_CHUNK];
} sink_dest;

static void init_destination(j_compress_ptr cinfo) {
  sink_dest *d = (sink_dest *) cinfo->dest;
  d->pub.next_output_byte = d->buf;
  d->pub.free_in_buffer = OUT_CHUNK;
}

static boolean empty_output_buffer(j_compress_ptr cinfo) {
  sink_dest *d = (sink_dest *) cinfo->dest;
  if (d->write(d->closure, d->buf, OUT_CHUNK) != 0) {
    d->sink_failed = 1;
    longjmp(d->jmp->env, 1);
  }
  d->pub.next_output_byte = d->buf;
  d->pub.free_in_buffer = OUT_CHUNK;
  return TRUE;
}

static void term_destination(j_compress_ptr cinfo) {
  sink_dest *d = (sink_dest *) cinfo->dest;
  size_t n = OUT_CHUNK - d->pub.free_in_buffer;
  if (n > 0 && d->write(d->closure, d->buf, n) != 0) {
    d->sink_failed = 1;
    longjmp(d->jmp->env, 1);
  }
}

zpx_status zpx_int_encode_jpeg(const uint8_t *src, uint32_t width,
                               uint32_t height, int channels,
                               const zpx_jpeg_opts *opts, zpx_write_fn write,
                               void *closure, const char **detail) {
  struct jpeg_compress_struct cinfo;
  struct jpeg_error_mgr jerr;
  zpx_jpeg_jmp jmp;
  sink_dest dest;
  size_t row;

  if ((channels != 1 && channels != 3) || width == 0 || height == 0 ||
      opts->quality < 1 || opts->quality > 100 || opts->subsampling < 0 ||
      opts->subsampling > 2) {
    *detail = "invalid JPEG channels, size, quality or subsampling";
    return ZPX_ERR_ARGUMENT;
  }
  if (width > 65535 || height > 65535) {
    *detail = "JPEG holds at most 65,535 pixels a side";
    return ZPX_ERR_ENCODE;
  }
  if (opts->exif_len > 65533 - 6) {
    *detail = "the EXIF block is too large for a JPEG APP1 segment";
    return ZPX_ERR_ENCODE;
  }
  row = (size_t) width * (size_t) channels;

  memset(&cinfo, 0, sizeof cinfo);
  memset(&dest, 0, sizeof dest);
  jmp.message[0] = '\0';
  cinfo.err = jpeg_std_error(&jerr);
  cinfo.client_data = &jmp;
  dest.write = write;
  dest.closure = closure;
  dest.jmp = &jmp;

  /* cinfo and dest are only changed through pointers between here and a
   * longjmp, so they are intact when it lands. */
  if (setjmp(jmp.env)) {
    jpeg_destroy_compress(&cinfo);
    if (dest.sink_failed) return ZPX_ERR_SINK;
    *detail = "libjpeg-turbo failed to encode the image";
    return ZPX_ERR_ENCODE;
  }

  jpeg_create_compress(&cinfo);
  dest.pub.init_destination = init_destination;
  dest.pub.empty_output_buffer = empty_output_buffer;
  dest.pub.term_destination = term_destination;
  cinfo.dest = &dest.pub;

  cinfo.image_width = width;
  cinfo.image_height = height;
  cinfo.input_components = channels;
  cinfo.in_color_space = channels == 1 ? JCS_GRAYSCALE : JCS_RGB;
  jpeg_set_defaults(&cinfo);
  jpeg_set_quality(&cinfo, opts->quality, TRUE);
  cinfo.optimize_coding = TRUE;
  if (channels == 3) {
    /* Luma at 1x1; chroma sampled 4:4:4, 4:2:2 or 4:2:0. */
    static const int h[3] = {1, 2, 2}, v[3] = {1, 1, 2};
    cinfo.comp_info[0].h_samp_factor = h[opts->subsampling];
    cinfo.comp_info[0].v_samp_factor = v[opts->subsampling];
    cinfo.comp_info[1].h_samp_factor = cinfo.comp_info[1].v_samp_factor = 1;
    cinfo.comp_info[2].h_samp_factor = cinfo.comp_info[2].v_samp_factor = 1;
  }
  if (opts->progressive) jpeg_simple_progression(&cinfo);

  jpeg_start_compress(&cinfo, TRUE);
  if (opts->exif && opts->exif_len > 0) {
    /* APP1: "Exif\0\0" then the TIFF block. */
    jpeg_write_m_header(&cinfo, JPEG_APP0 + 1,
                        (unsigned int) (6 + opts->exif_len));
    for (int i = 0; i < 6; i++)
      jpeg_write_m_byte(&cinfo, "Exif\0\0"[i]);
    for (size_t i = 0; i < opts->exif_len; i++)
      jpeg_write_m_byte(&cinfo, opts->exif[i]);
  }
  if (opts->icc && opts->icc_len > 0)
    jpeg_write_icc_profile(&cinfo, opts->icc, (unsigned int) opts->icc_len);

  while (cinfo.next_scanline < cinfo.image_height) {
    JSAMPROW r = (JSAMPROW) (src + (size_t) cinfo.next_scanline * row);
    jpeg_write_scanlines(&cinfo, &r, 1);
  }
  jpeg_finish_compress(&cinfo);
  jpeg_destroy_compress(&cinfo);
  return ZPX_OK;
}
