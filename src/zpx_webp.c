/* WebP encoding through libwebp's encoder (design §4.2), threads off.
 * libwebp produces a complete RIFF file; zupix adds VP8X, ICCP and EXIF
 * around its bitstream itself (D14), so libwebpmux is not vendored. */

#include <stdlib.h>
#include <string.h>

#include "src/webp/encode.h"

#include "zpx_core.h"
#include "zpx_int.h"

int zpx_int_webp_encoder_version(void) {
  return WebPGetEncoderVersion();
}

static void le24(uint8_t *p, uint32_t v) {
  p[0] = (uint8_t) v;
  p[1] = (uint8_t) (v >> 8);
  p[2] = (uint8_t) (v >> 16);
}
static void le32(uint8_t *p, uint32_t v) {
  le24(p, v);
  p[3] = (uint8_t) (v >> 24);
}

typedef struct {
  zpx_write_fn write;
  void *closure;
  int failed;
} out_t;

/* Untested, as are the ZPX_ERR_SINK returns it leads to: R's sink fails
 * only when out of memory (zpx_sink.c). */
static void put(out_t *o, const uint8_t *p, size_t n) {
  if (!o->failed && n > 0 && o->write(o->closure, p, n) != 0) o->failed = 1;
}

static void chunk(out_t *o, const char *fourcc, const uint8_t *p, size_t n) {
  uint8_t head[8], pad = 0;
  memcpy(head, fourcc, 4);
  le32(head + 4, (uint32_t) n);
  put(o, head, 8);
  put(o, p, n);
  if (n & 1) put(o, &pad, 1);
}

/* Writes `file` (libwebp's output) with ICCP and EXIF added: a VP8X chunk
 * (libwebp's, with its flags extended, or a new one), ICCP right after it,
 * the image chunks, EXIF last. */
static zpx_status wrap(const uint8_t *file, size_t len, uint32_t width,
                       uint32_t height, int alpha, const zpx_webp_opts *opts,
                       out_t *o) {
  size_t pos = 12, body;
  uint8_t vp8x[10], head[12];
  int has_icc = opts->icc && opts->icc_len > 0;
  int has_exif = opts->exif && opts->exif_len > 0;
  size_t icc_pad = has_icc ? opts->icc_len + (opts->icc_len & 1) : 0;
  size_t exif_pad = has_exif ? opts->exif_len + (opts->exif_len & 1) : 0;

  if (!has_icc && !has_exif) {
    put(o, file, len);
    return o->failed ? ZPX_ERR_SINK : ZPX_OK;
  }
  /* Untested: libwebp always writes a RIFF file of at least 20 bytes. */
  if (len < 20 || memcmp(file, "RIFF", 4) != 0) return ZPX_ERR_ENCODE;

  memset(vp8x, 0, sizeof vp8x);
  if (memcmp(file + 12, "VP8X", 4) == 0) {
    memcpy(vp8x, file + 20, 10);
    pos = 12 + 8 + 10;
  } else {
    vp8x[0] = alpha ? 0x10 : 0;
    le24(vp8x + 4, width - 1);
    le24(vp8x + 7, height - 1);
  }
  if (has_icc) vp8x[0] |= 0x20;
  if (has_exif) vp8x[0] |= 0x08;

  /* "WEBP", VP8X, ICCP, the image chunks, EXIF. */
  body = 4 + 18 + (has_icc ? 8 + icc_pad : 0) + (len - pos) +
         (has_exif ? 8 + exif_pad : 0);
  if (body > 0xfffffff0u) return ZPX_ERR_ENCODE; /* Untested: a 4 GiB file */
  memcpy(head, "RIFF", 4);
  le32(head + 4, (uint32_t) body);
  memcpy(head + 8, "WEBP", 4);
  put(o, head, 12);
  chunk(o, "VP8X", vp8x, 10);
  if (has_icc) chunk(o, "ICCP", opts->icc, opts->icc_len);
  put(o, file + pos, len - pos);
  if (has_exif) chunk(o, "EXIF", opts->exif, opts->exif_len);
  return o->failed ? ZPX_ERR_SINK : ZPX_OK;
}

zpx_status zpx_int_encode_webp(const uint8_t *src, uint32_t width,
                               uint32_t height, int channels,
                               const zpx_webp_opts *opts, zpx_write_fn write,
                               void *closure, const char **detail) {
  WebPConfig config;
  WebPPicture pic;
  WebPMemoryWriter mem;
  out_t o = {write, closure, 0};
  zpx_status s;
  int ok;

  if ((channels != 3 && channels != 4) || width == 0 || height == 0 ||
      opts->quality < 0 || opts->quality > 100 || opts->method < 0 ||
      opts->method > 6) {
    *detail = "invalid WebP channels, size, quality or method";
    return ZPX_ERR_ARGUMENT;
  }
  if (width > WEBP_MAX_DIMENSION || height > WEBP_MAX_DIMENSION) {
    *detail = "WebP holds at most 16,383 pixels a side";
    return ZPX_ERR_ENCODE;
  }
  /* Untested: fails only on a libwebp ABI mismatch, fixed at build time. */
  if (!WebPConfigInit(&config) || !WebPPictureInit(&pic)) {
    *detail = "libwebp version mismatch";
    return ZPX_ERR_ENCODE;
  }
  config.quality = opts->quality;
  config.lossless = opts->lossless;
  config.method = opts->method;
  config.thread_level = 0;
  if (opts->lossless) {
    /* Keep the RGB under fully transparent pixels: lossless means exact. */
    config.exact = 1;
  }
  if (!WebPValidateConfig(&config)) {
    *detail = "invalid WebP configuration";
    return ZPX_ERR_ARGUMENT;
  }
  pic.use_argb = opts->lossless;
  pic.width = (int) width;
  pic.height = (int) height;
  ok = channels == 4
           ? WebPPictureImportRGBA(&pic, src, (int) (width * 4))
           : WebPPictureImportRGB(&pic, src, (int) (width * 3));
  if (!ok) { /* Untested: allocation */
    WebPPictureFree(&pic);
    return ZPX_ERR_MEMORY;
  }
  WebPMemoryWriterInit(&mem);
  pic.writer = WebPMemoryWrite;
  pic.custom_ptr = &mem;
  ok = WebPEncode(&config, &pic);
  if (!ok) {
    /* Untested: with the size and options checked above, libwebp fails
     * only when out of memory. */
    *detail = pic.error_code == VP8_ENC_ERROR_OUT_OF_MEMORY
                  ? "out of memory"
                  : "libwebp failed to encode the image";
    s = pic.error_code == VP8_ENC_ERROR_OUT_OF_MEMORY ? ZPX_ERR_MEMORY
                                                       : ZPX_ERR_ENCODE;
  } else {
    s = wrap(mem.mem, mem.size, width, height, channels == 4, opts, &o);
  }
  WebPPictureFree(&pic);
  WebPMemoryWriterClear(&mem);
  return s;
}
