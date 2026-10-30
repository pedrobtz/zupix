/* Probing and decoding through Wuffs (design §4.1, §6.5). This file sees
 * only the declaration half of wuffs-v0.4.c; zpx_wuffs.c compiles the
 * implementation. Decoders, work buffers and the still image built from an
 * animated WebP are allocated and freed inside each call, which never calls
 * R, so nothing can leak across an R error. */

#include <stdlib.h>
#include <string.h>

#define WUFFS_CONFIG__MODULES
#define WUFFS_CONFIG__MODULE__BASE
#define WUFFS_CONFIG__MODULE__ADLER32
#define WUFFS_CONFIG__MODULE__CRC32
#define WUFFS_CONFIG__MODULE__DEFLATE
#define WUFFS_CONFIG__MODULE__ZLIB
#define WUFFS_CONFIG__MODULE__PNG
#define WUFFS_CONFIG__MODULE__JPEG
#define WUFFS_CONFIG__MODULE__VP8
#define WUFFS_CONFIG__MODULE__WEBP
#define WUFFS_CONFIG__MODULE__QOI
#include "vendor/wuffs/wuffs-v0.4.c"

#include "zpx_core.h"

/* A decoder for one format. Its functions are called directly, never
 * through Wuffs's generic wuffs_base__image_decoder: that interface calls
 * them through a pointer whose `self` type is void *, which clang's
 * -fsanitize=function (part of CRAN's UBSan check) reports as undefined
 * behaviour. `still` is an animated WebP's first frame rebuilt as a still
 * WebP, which is what Wuffs is given instead of the file. */
typedef struct {
  zpx_format format;
  void *mem;
  uint8_t *still;
} zpx_decoder;

static void free_decoder(zpx_decoder *d) {
  free(d->mem);
  free(d->still);
  d->mem = NULL;
  d->still = NULL;
}

static wuffs_base__status decode_image_config(zpx_decoder *d,
                                              wuffs_base__image_config *ic,
                                              wuffs_base__io_buffer *src) {
  switch (d->format) {
  case ZPX_FMT_PNG:
    return wuffs_png__decoder__decode_image_config(d->mem, ic, src);
  case ZPX_FMT_JPEG:
    return wuffs_jpeg__decoder__decode_image_config(d->mem, ic, src);
  case ZPX_FMT_WEBP:
    return wuffs_webp__decoder__decode_image_config(d->mem, ic, src);
  default:
    return wuffs_qoi__decoder__decode_image_config(d->mem, ic, src);
  }
}

static uint64_t workbuf_len(zpx_decoder *d) {
  switch (d->format) {
  case ZPX_FMT_PNG: return wuffs_png__decoder__workbuf_len(d->mem).max_incl;
  case ZPX_FMT_JPEG: return wuffs_jpeg__decoder__workbuf_len(d->mem).max_incl;
  case ZPX_FMT_WEBP: return wuffs_webp__decoder__workbuf_len(d->mem).max_incl;
  default: return wuffs_qoi__decoder__workbuf_len(d->mem).max_incl;
  }
}

static wuffs_base__status decode_frame(zpx_decoder *d,
                                       wuffs_base__pixel_buffer *pb,
                                       wuffs_base__io_buffer *src,
                                       wuffs_base__slice_u8 work) {
  wuffs_base__pixel_blend b = WUFFS_BASE__PIXEL_BLEND__SRC;
  switch (d->format) {
  case ZPX_FMT_PNG:
    return wuffs_png__decoder__decode_frame(d->mem, pb, src, b, work, NULL);
  case ZPX_FMT_JPEG:
    return wuffs_jpeg__decoder__decode_frame(d->mem, pb, src, b, work, NULL);
  case ZPX_FMT_WEBP:
    return wuffs_webp__decoder__decode_frame(d->mem, pb, src, b, work, NULL);
  default:
    return wuffs_qoi__decoder__decode_frame(d->mem, pb, src, b, work, NULL);
  }
}

static zpx_status new_decoder(zpx_format format, zpx_decoder *d,
                              const char **detail) {
  size_t size;
  wuffs_base__status st;

  d->format = format;
  switch (format) {
  case ZPX_FMT_PNG: size = sizeof__wuffs_png__decoder(); break;
  case ZPX_FMT_JPEG: size = sizeof__wuffs_jpeg__decoder(); break;
  case ZPX_FMT_WEBP: size = sizeof__wuffs_webp__decoder(); break;
  case ZPX_FMT_QOI: size = sizeof__wuffs_qoi__decoder(); break;
  default:
    *detail = "not a PNG, JPEG, WebP or QOI signature";
    return ZPX_ERR_FORMAT;
  }
  d->mem = calloc(1, size);
  if (d->mem == NULL) return ZPX_ERR_MEMORY;
  switch (format) {
  case ZPX_FMT_PNG:
    st = wuffs_png__decoder__initialize(d->mem, size, WUFFS_VERSION, 0);
    break;
  case ZPX_FMT_JPEG:
    st = wuffs_jpeg__decoder__initialize(d->mem, size, WUFFS_VERSION, 0);
    break;
  case ZPX_FMT_WEBP:
    st = wuffs_webp__decoder__initialize(d->mem, size, WUFFS_VERSION, 0);
    break;
  default:
    st = wuffs_qoi__decoder__initialize(d->mem, size, WUFFS_VERSION, 0);
    break;
  }
  if (!wuffs_base__status__is_ok(&st)) {
    *detail = wuffs_base__status__message(&st);
    return ZPX_ERR_DECODE;
  }
  return ZPX_OK;
}

/* Wuffs's errors for valid but unsupported input; everything else it
 * reports is a corrupt or truncated file. */
static zpx_status wuffs_failure(const wuffs_base__status *st) {
  const char *m = wuffs_base__status__message(st);
  if (m && strstr(m, "unsupported")) return ZPX_ERR_UNSUPPORTED;
  return ZPX_ERR_DECODE;
}

static zpx_status limit(zpx_int_probe *out, zpx_limit_kind kind,
                        uint64_t value, uint64_t cap) {
  out->limit = kind;
  out->limit_value = value;
  out->limit_cap = cap;
  return ZPX_ERR_LIMIT;
}

/* Scans the container, configures the decoder, checks the limits that
 * depend on the header alone, and leaves the decoder and its input in `d`
 * and `src` for decoding. */
static zpx_status probe(const uint8_t *buf, size_t len,
                        const zpx_limits *limits, zpx_int_probe *out,
                        zpx_decoder *d, wuffs_base__image_config *ic,
                        wuffs_base__io_buffer *src) {
  zpx_status s;
  wuffs_base__status st;
  uint64_t pixels;
  const zpx_meta *m = &out->meta;
  const uint8_t *in = buf;
  size_t in_len = len;

  memset(out, 0, sizeof *out);
  d->format = ZPX_FMT_UNKNOWN;
  d->mem = NULL; /* the callers free both on every path */
  d->still = NULL;

  s = zpx_int_scan(buf, len, limits, &out->meta, &out->detail);
  if (s == ZPX_ERR_LIMIT)
    return limit(out, ZPX_LIMIT_METADATA,
                 (uint64_t) out->meta.icc_len + out->meta.exif_len,
                 limits->max_metadata);
  if (s != ZPX_OK) return s;
  out->format = m->format;
  out->width = m->width;
  out->height = m->height;
  out->channels = m->channels;
  out->bits = m->format == ZPX_FMT_PNG && m->bits == 16 ? 16 : 8;

  /* Side and pixel limits on the scanner's declared size, before even the
   * decoder is allocated. */
  if (out->width > limits->max_side)
    return limit(out, ZPX_LIMIT_SIDE, out->width, limits->max_side);
  if (out->height > limits->max_side)
    return limit(out, ZPX_LIMIT_SIDE, out->height, limits->max_side);
  pixels = (uint64_t) out->width * (uint64_t) out->height;
  if (pixels > limits->max_pixels)
    return limit(out, ZPX_LIMIT_PIXELS, pixels, limits->max_pixels);

  if (m->format == ZPX_FMT_WEBP && (m->animated || m->webp_rebuild)) {
    /* D13: an animated file's first frame. Wuffs decodes still WebP only,
     * so the frame's chunks are rebuilt as one; compositing a frame smaller
     * than the canvas is not implemented. An extended still file with a
     * VP8L bitstream is rebuilt the same way (see zpx_meta.webp_rebuild). */
    if (m->frame_len == 0) {
      out->detail = "animated WebP has no frames";
      return ZPX_ERR_DECODE;
    }
    if (m->frame_x != 0 || m->frame_y != 0 || m->frame_w != m->width ||
        m->frame_h != m->height) {
      out->detail = "animated WebP whose first frame does not cover the "
                    "canvas";
      return ZPX_ERR_UNSUPPORTED;
    }
    d->still = malloc(m->frame_len + 30);
    if (d->still == NULL) return ZPX_ERR_MEMORY;
    in_len = zpx_int_webp_first_frame(buf, m, d->still);
    in = d->still;
  }

  s = new_decoder(m->format, d, &out->detail);
  if (s != ZPX_OK) return s;

  *src = wuffs_base__ptr_u8__reader((uint8_t *) in, in_len, true);
  memset(ic, 0, sizeof *ic);
  st = decode_image_config(d, ic, src);
  if (!wuffs_base__status__is_ok(&st)) {
    out->detail = wuffs_base__status__message(&st);
    return wuffs_failure(&st);
  }
  /* A crafted header must not pass the limits with one size and decode
   * with another (design §6.4). */
  if (wuffs_base__pixel_config__width(&ic->pixcfg) != out->width ||
      wuffs_base__pixel_config__height(&ic->pixcfg) != out->height) {
    out->detail = "the container and the decoder disagree on the image size";
    return ZPX_ERR_DECODE;
  }
  out->workbuf_len = workbuf_len(d);
  if (out->workbuf_len > limits->max_bytes)
    return limit(out, ZPX_LIMIT_BYTES, out->workbuf_len, limits->max_bytes);
  return ZPX_OK;
}

zpx_status zpx_int_probe_image(const uint8_t *buf, size_t len,
                               const zpx_limits *limits, zpx_int_probe *out) {
  zpx_decoder d;
  wuffs_base__image_config ic;
  wuffs_base__io_buffer src;
  zpx_status s = probe(buf, len, limits, out, &d, &ic, &src);
  free_decoder(&d);
  return s;
}

zpx_status zpx_int_decode_image(const uint8_t *buf, size_t len,
                                const zpx_limits *limits, zpx_pixfmt pixfmt,
                                uint8_t *dst, size_t stride, size_t dst_len,
                                zpx_int_probe *out) {
  zpx_decoder d;
  wuffs_base__image_config ic;
  wuffs_base__io_buffer src;
  wuffs_base__pixel_config pc;
  wuffs_base__pixel_buffer pb;
  wuffs_base__status st;
  uint32_t wuffs_fmt;
  size_t bpp, row;
  void *work = NULL;
  zpx_status s;

  s = probe(buf, len, limits, out, &d, &ic, &src);
  if (s != ZPX_OK) goto done;

  switch (pixfmt) {
  case ZPX_PIX_RGBA8:
    wuffs_fmt = WUFFS_BASE__PIXEL_FORMAT__RGBA_NONPREMUL;
    bpp = 4;
    break;
  case ZPX_PIX_RGBA16:
    wuffs_fmt = WUFFS_BASE__PIXEL_FORMAT__BGRA_NONPREMUL_4X16LE;
    bpp = 8;
    break;
  default:
    out->detail = "unsupported destination pixel format";
    s = ZPX_ERR_ARGUMENT;
    goto done;
  }
  row = (size_t) out->width * bpp;
  if (out->width != 0 && row / bpp != out->width) {
    s = ZPX_ERR_ARGUMENT;
    goto done;
  }
  if (dst == NULL || stride < row ||
      (out->height > 0 && (stride > SIZE_MAX / out->height ||
                           stride * out->height > dst_len))) {
    out->detail = "destination buffer is too small";
    s = ZPX_ERR_ARGUMENT;
    goto done;
  }

  if (out->workbuf_len > 0) {
    work = malloc((size_t) out->workbuf_len);
    if (work == NULL) {
      s = ZPX_ERR_MEMORY;
      goto done;
    }
  }
  wuffs_base__pixel_config__set(&pc, wuffs_fmt,
                                WUFFS_BASE__PIXEL_SUBSAMPLING__NONE,
                                out->width, out->height);
  st = wuffs_base__pixel_buffer__set_interleaved(
      &pb, &pc, wuffs_base__make_table_u8(dst, row, out->height, stride),
      wuffs_base__empty_slice_u8());
  if (!wuffs_base__status__is_ok(&st)) {
    out->detail = wuffs_base__status__message(&st);
    s = ZPX_ERR_ARGUMENT;
    goto done;
  }
  st = decode_frame(
      &d, &pb, &src,
      wuffs_base__make_slice_u8((uint8_t *) work, (size_t) out->workbuf_len));
  if (!wuffs_base__status__is_ok(&st)) {
    /* A truncated or corrupt file is an error, never a partial image. */
    out->detail = wuffs_base__status__message(&st);
    s = wuffs_failure(&st);
    goto done;
  }
  s = ZPX_OK;

done:
  free(work);
  free_decoder(&d);
  return s;
}
