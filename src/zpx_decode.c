/* Probing and decoding through Wuffs (design §4.1, §6.5). This file sees
 * only the declaration half of wuffs-v0.4.c; zpx_wuffs.c compiles the
 * implementation. Decoders and work buffers are allocated and freed inside
 * each call, which never calls R, so nothing can leak across an R error. */

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

/* A PNG or QOI decoder. Its functions are called directly, never through
 * Wuffs's generic wuffs_base__image_decoder: that interface calls them
 * through a pointer whose `self` type is void *, which clang's
 * -fsanitize=function (part of CRAN's UBSan check) reports as undefined
 * behaviour. */
typedef struct {
  zpx_format format;
  void *mem;
} zpx_decoder;

static wuffs_base__status decode_image_config(zpx_decoder *d,
                                              wuffs_base__image_config *ic,
                                              wuffs_base__io_buffer *src) {
  if (d->format == ZPX_FMT_PNG)
    return wuffs_png__decoder__decode_image_config(
        (wuffs_png__decoder *) d->mem, ic, src);
  return wuffs_qoi__decoder__decode_image_config(
      (wuffs_qoi__decoder *) d->mem, ic, src);
}

static uint64_t workbuf_len(zpx_decoder *d) {
  if (d->format == ZPX_FMT_PNG)
    return wuffs_png__decoder__workbuf_len((wuffs_png__decoder *) d->mem)
        .max_incl;
  return wuffs_qoi__decoder__workbuf_len((wuffs_qoi__decoder *) d->mem)
      .max_incl;
}

static wuffs_base__status decode_frame(zpx_decoder *d,
                                       wuffs_base__pixel_buffer *pb,
                                       wuffs_base__io_buffer *src,
                                       wuffs_base__slice_u8 work) {
  if (d->format == ZPX_FMT_PNG)
    return wuffs_png__decoder__decode_frame(
        (wuffs_png__decoder *) d->mem, pb, src, WUFFS_BASE__PIXEL_BLEND__SRC,
        work, NULL);
  return wuffs_qoi__decoder__decode_frame(
      (wuffs_qoi__decoder *) d->mem, pb, src, WUFFS_BASE__PIXEL_BLEND__SRC,
      work, NULL);
}

static zpx_status new_decoder(zpx_format format, zpx_decoder *d,
                              const char **detail) {
  size_t size;
  wuffs_base__status st;

  d->format = format;
  d->mem = NULL;
  switch (format) {
  case ZPX_FMT_PNG: size = sizeof__wuffs_png__decoder(); break;
  case ZPX_FMT_QOI: size = sizeof__wuffs_qoi__decoder(); break;
  default:
    *detail = "decoding this format is not available yet";
    return ZPX_ERR_UNSUPPORTED;
  }
  d->mem = calloc(1, size);
  if (d->mem == NULL) return ZPX_ERR_MEMORY;
  if (format == ZPX_FMT_PNG) {
    st = wuffs_png__decoder__initialize((wuffs_png__decoder *) d->mem, size,
                                        WUFFS_VERSION, 0);
  } else {
    st = wuffs_qoi__decoder__initialize((wuffs_qoi__decoder *) d->mem, size,
                                        WUFFS_VERSION, 0);
  }
  if (!wuffs_base__status__is_ok(&st)) {
    *detail = wuffs_base__status__message(&st);
    free(d->mem);
    d->mem = NULL;
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

/* The header, the limits that depend on it alone, and the source depth
 * and channels; leaves the configured decoder in `d` for decoding. */
static zpx_status probe(const uint8_t *buf, size_t len,
                        const zpx_limits *limits, zpx_int_probe *out,
                        zpx_decoder *d, wuffs_base__image_config *ic,
                        wuffs_base__io_buffer *src) {
  zpx_status s;
  wuffs_base__status st;
  uint64_t pixels;

  memset(out, 0, sizeof *out);
  d->format = ZPX_FMT_UNKNOWN;
  d->mem = NULL; /* the callers free it on every path */
  out->format = zpx_sniff(buf, len);
  if (out->format == ZPX_FMT_UNKNOWN) {
    out->detail = "not a PNG, JPEG, WebP or QOI signature";
    return ZPX_ERR_FORMAT;
  }
  s = new_decoder(out->format, d, &out->detail);
  if (s != ZPX_OK) return s;

  *src = wuffs_base__ptr_u8__reader((uint8_t *) buf, len, true);
  memset(ic, 0, sizeof *ic);
  st = decode_image_config(d, ic, src);
  if (!wuffs_base__status__is_ok(&st)) {
    out->detail = wuffs_base__status__message(&st);
    return wuffs_failure(&st);
  }
  out->width = wuffs_base__pixel_config__width(&ic->pixcfg);
  out->height = wuffs_base__pixel_config__height(&ic->pixcfg);
  out->workbuf_len = workbuf_len(d);

  if (out->format == ZPX_FMT_PNG) {
    zpx_png_header h;
    s = zpx_int_png_header(buf, len, &h, &out->detail);
    if (s != ZPX_OK) return s;
    /* A crafted header must not pass the limits with one size and decode
     * with another (design §6.4). */
    if (h.width != out->width || h.height != out->height) {
      out->detail = "PNG header and decoder disagree on the image size";
      return ZPX_ERR_DECODE;
    }
    out->bits = h.depth == 16 ? 16 : 8;
    switch (h.colour_type) {
    case 0: out->channels = h.has_trns ? 2 : 1; break;
    case 2: out->channels = h.has_trns ? 4 : 3; break;
    case 3: out->channels = h.has_trns ? 4 : 3; break;
    case 4: out->channels = 2; break;
    case 6: out->channels = 4; break;
    default:
      out->detail = "PNG colour type is invalid";
      return ZPX_ERR_DECODE;
    }
  } else {
    /* QOI: 14-byte header, channels at byte 12; Wuffs has validated it. */
    out->bits = 8;
    out->channels = buf[12] == 3 ? 3 : 4;
  }

  if (out->width > limits->max_side)
    return limit(out, ZPX_LIMIT_SIDE, out->width, limits->max_side);
  if (out->height > limits->max_side)
    return limit(out, ZPX_LIMIT_SIDE, out->height, limits->max_side);
  pixels = (uint64_t) out->width * (uint64_t) out->height;
  if (pixels > limits->max_pixels)
    return limit(out, ZPX_LIMIT_PIXELS, pixels, limits->max_pixels);
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
  free(d.mem);
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
  {
    wuffs_base__table_u8 t = wuffs_base__make_table_u8(
        dst, row, out->height, stride);
    st = wuffs_base__pixel_buffer__set_interleaved(&pb, &pc, t,
                                                   wuffs_base__empty_slice_u8());
  }
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
  free(d.mem);
  return s;
}
