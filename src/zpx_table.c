/* The C table other packages call (design §7, D11): zupix_api_v1 over the
 * R-free core, registered as "zupix_get_api" by R_init_zupix. Nothing here
 * calls R or raises an R error, so a consumer may call in from inside a
 * vendored library's frames. Buffers it allocates are freed before it
 * returns. */

#include <stdlib.h>
#include <string.h>

#include "zpx_core.h"
#include "zpx_table.h"

static const zpx_limits *limits_or_default(const zpx_limits *l,
                                           zpx_limits *defaults) {
  if (l != NULL) return l;
  defaults->struct_size = (uint32_t) sizeof *defaults;
  defaults->max_side = 65535u;
  defaults->max_pixels = 100000000ull;
  defaults->max_bytes = 2147483648ull;
  defaults->max_metadata = 16ull << 20;
  return defaults;
}

/* Bytes per pixel and channels of a layout; 0 for an unknown one. */
static size_t layout(zpx_pixfmt f, int *channels, int *bits) {
  switch (f) {
  case ZPX_PIX_RGBA8: *channels = 4; *bits = 8; return 4;
  case ZPX_PIX_RGB8: *channels = 3; *bits = 8; return 3;
  case ZPX_PIX_Y8: *channels = 1; *bits = 8; return 1;
  case ZPX_PIX_RGBA16: *channels = 4; *bits = 16; return 8;
  case ZPX_PIX_Y16: *channels = 1; *bits = 16; return 2;
  default: return 0;
  }
}

static uint64_t mul64(uint64_t a, uint64_t b) {
  if (a != 0 && b > UINT64_MAX / a) return UINT64_MAX;
  return a * b;
}

static zpx_format api_sniff(const uint8_t *buf, size_t len) {
  return zpx_sniff(buf, len);
}

static zpx_status api_probe(const uint8_t *buf, size_t len,
                            const zpx_limits *limits, zpx_info *info) {
  zpx_limits d;
  zpx_int_probe p;
  zpx_status s;
  if (buf == NULL || info == NULL || info->struct_size < sizeof *info)
    return ZPX_ERR_ARGUMENT;
  s = zpx_int_probe_image(buf, len, limits_or_default(limits, &d), &p);
  if (s != ZPX_OK) return s;
  info->format = p.format;
  info->width = p.width;
  info->height = p.height;
  info->bits = p.bits;
  info->channels = p.channels;
  info->orientation = (uint8_t) p.meta.orientation;
  info->animated = (uint8_t) p.meta.animated;
  info->icc_len = p.meta.icc_len;
  info->exif_len = p.meta.exif_len;
  return ZPX_OK;
}

/* One sample of the RGBA intermediate: RGBA8 bytes, or Wuffs's BGRA
 * 16-bit little-endian. */
static unsigned sample(const uint8_t *px, int wide, int c) {
  static const int map[4] = {2, 1, 0, 3};
  const uint8_t *p;
  if (!wide) return px[c];
  p = px + 2 * map[c];
  return (unsigned) p[0] | ((unsigned) p[1] << 8);
}

static zpx_status api_decode(const uint8_t *buf, size_t len,
                             const zpx_limits *limits, zpx_pixfmt pixfmt,
                             uint8_t *dst, size_t stride, size_t dst_len) {
  zpx_limits d;
  const zpx_limits *lim = limits_or_default(limits, &d);
  zpx_int_probe p;
  zpx_status s;
  int channels, bits, wide;
  size_t bpp = layout(pixfmt, &channels, &bits), row, ibpp;
  uint64_t inter;
  uint8_t *tmp;

  if (bpp == 0 || buf == NULL || dst == NULL) return ZPX_ERR_ARGUMENT;
  s = zpx_int_probe_image(buf, len, lim, &p);
  if (s != ZPX_OK) return s;
  /* Channels may be added, never removed (design D10): no alpha dropped,
   * no colour image made grey. */
  if ((p.channels == 2 || p.channels == 4) && channels != 4)
    return ZPX_ERR_ARGUMENT;
  if (p.channels >= 3 && channels == 1) return ZPX_ERR_ARGUMENT;
  row = (size_t) p.width * bpp;
  if (p.width != 0 && row / bpp != p.width) return ZPX_ERR_ARGUMENT;
  if (stride < row || (p.height > 0 && (stride > SIZE_MAX / p.height ||
                                        stride * p.height > dst_len)))
    return ZPX_ERR_ARGUMENT;

  wide = p.bits == 16;
  /* The common case decodes straight into the caller's buffer. */
  if (pixfmt == ZPX_PIX_RGBA8 && !wide)
    return zpx_int_decode_image(buf, len, lim, ZPX_PIX_RGBA8, dst, stride,
                                dst_len, &p);
  if (pixfmt == ZPX_PIX_RGBA16 && wide) {
    /* Wuffs writes BGRA little-endian; decode, then reorder in place. */
    s = zpx_int_decode_image(buf, len, lim, ZPX_PIX_RGBA16, dst, stride,
                             dst_len, &p);
    if (s != ZPX_OK) return s;
    for (uint32_t y = 0; y < p.height; y++) {
      uint8_t *r = dst + (size_t) y * stride;
      for (uint32_t x = 0; x < p.width; x++) {
        uint8_t *px = r + 8 * (size_t) x;
        uint16_t v[4];
        for (int c = 0; c < 4; c++) v[c] = (uint16_t) sample(px, 1, c);
        memcpy(px, v, 8);
      }
    }
    return ZPX_OK;
  }

  /* Everything else goes through an RGBA intermediate, counted against
   * max_bytes with the decoder's work buffer. */
  ibpp = wide ? 8 : 4;
  inter = mul64((uint64_t) p.width * p.height, ibpp);
  if (inter == UINT64_MAX || inter + p.workbuf_len > lim->max_bytes ||
      inter > SIZE_MAX)
    return ZPX_ERR_LIMIT;
  tmp = (uint8_t *) malloc((size_t) inter + 1);
  if (tmp == NULL) return ZPX_ERR_MEMORY;
  s = zpx_int_decode_image(buf, len, lim, wide ? ZPX_PIX_RGBA16 : ZPX_PIX_RGBA8,
                           tmp, (size_t) p.width * ibpp, (size_t) inter, &p);
  if (s == ZPX_OK) {
    for (uint32_t y = 0; y < p.height; y++) {
      uint8_t *out = dst + (size_t) y * stride;
      for (uint32_t x = 0; x < p.width; x++) {
        const uint8_t *px = tmp + ((size_t) y * p.width + x) * ibpp;
        for (int c = 0; c < channels; c++) {
          /* Grey output takes R: the source is grey, so R = G = B. */
          unsigned v = sample(px, wide, channels == 1 ? 0 : c);
          if (wide && bits == 8) v = (v + 128u) / 257u;
          if (!wide && bits == 16) v *= 257u;
          if (bits == 8) {
            out[(size_t) x * channels + c] = (uint8_t) v;
          } else {
            uint16_t u = (uint16_t) v;
            memcpy(out + 2 * ((size_t) x * channels + c), &u, 2);
          }
        }
      }
    }
  }
  free(tmp);
  return s;
}

static zpx_status api_metadata(const uint8_t *buf, size_t len,
                               uint32_t fourcc, uint8_t *dst,
                               size_t *out_len) {
  zpx_limits d;
  const zpx_limits *lim = limits_or_default(NULL, &d);
  zpx_meta m;
  const char *detail = NULL;
  zpx_status s;
  if (buf == NULL || out_len == NULL) return ZPX_ERR_ARGUMENT;
  s = zpx_int_scan(buf, len, lim, &m, &detail);
  if (s != ZPX_OK) return s;
  if (fourcc == ZPX_META_ICC) {
    size_t need = 0, cap = *out_len;
    s = zpx_int_icc(buf, len, &m, lim, NULL, &need, &detail);
    if (s != ZPX_OK || dst == NULL) {
      *out_len = need;
      return s;
    }
    if (cap < need) return ZPX_ERR_ARGUMENT;
    *out_len = need;
    return zpx_int_icc(buf, len, &m, lim, dst, out_len, &detail);
  }
  if (fourcc == ZPX_META_EXIF) {
    if (dst != NULL) {
      if (*out_len < m.exif_len) return ZPX_ERR_ARGUMENT;
      memcpy(dst, buf + m.exif_off, m.exif_len);
    }
    *out_len = m.exif_len;
    return ZPX_OK;
  }
  return ZPX_ERR_ARGUMENT;
}

/* The encoder's tight interleaved input: `channels` at `bits` from the
 * caller's layout, with 16 bits rounded to 8 where `to8`, grey widened to
 * RGB where `widen`, and an opaque alpha dropped where `drop_alpha` (a
 * transparent pixel is ZPX_ERR_ARGUMENT). */
static zpx_status repack(const uint8_t *src, uint32_t w, uint32_t h,
                         size_t stride, int in_c, int in_bits, int to8,
                         int widen, int drop_alpha, uint8_t **out,
                         int *out_c, int *out_bits) {
  int oc = in_c, ob = to8 ? 8 : in_bits;
  size_t n;
  uint8_t *b;
  if (widen && in_c == 1) oc = 3;
  if (drop_alpha && in_c == 4) oc = 3;
  n = (size_t) w * h * (size_t) oc * (size_t) (ob / 8);
  b = (uint8_t *) malloc(n ? n : 1);
  if (b == NULL) return ZPX_ERR_MEMORY;
  for (uint32_t y = 0; y < h; y++) {
    const uint8_t *r = src + (size_t) y * stride;
    for (uint32_t x = 0; x < w; x++) {
      unsigned v[4];
      for (int c = 0; c < in_c; c++) {
        if (in_bits == 8) {
          v[c] = r[(size_t) x * in_c + c];
        } else {
          uint16_t u;
          memcpy(&u, r + 2 * ((size_t) x * in_c + c), 2);
          v[c] = u;
        }
      }
      if (drop_alpha && in_c == 4 && v[3] != (in_bits == 8 ? 255u : 65535u)) {
        free(b);
        return ZPX_ERR_ARGUMENT;
      }
      for (int c = 0; c < oc; c++) {
        unsigned s = v[in_c == 1 ? 0 : c];
        size_t at = ((size_t) y * w + x) * (size_t) oc + (size_t) c;
        if (in_bits == 16 && ob == 8) s = (s + 128u) / 257u;
        if (ob == 8) {
          b[at] = (uint8_t) s;
        } else {
          uint16_t u = (uint16_t) s;
          memcpy(b + 2 * at, &u, 2);
        }
      }
    }
  }
  *out = b;
  *out_c = oc;
  *out_bits = ob;
  return ZPX_OK;
}

static zpx_status api_encode(zpx_format format, zpx_pixfmt pixfmt,
                             const uint8_t *src, uint32_t width,
                             uint32_t height, size_t stride, const void *opts,
                             zpx_write_fn write, void *closure) {
  int in_c, in_bits, c, bits;
  size_t bpp = layout(pixfmt, &in_c, &in_bits);
  uint8_t *tight = NULL;
  const char *detail = NULL;
  zpx_status s;

  if (bpp == 0 || src == NULL || write == NULL || width == 0 || height == 0)
    return ZPX_ERR_ARGUMENT;
  if (stride < (size_t) width * bpp) return ZPX_ERR_ARGUMENT;
  /* A caller's options struct must be at least version 1's. */
  if (opts != NULL && *(const uint32_t *) opts <
                          (format == ZPX_FMT_PNG    ? sizeof(zpx_png_opts)
                           : format == ZPX_FMT_JPEG ? sizeof(zpx_jpeg_opts)
                           : format == ZPX_FMT_WEBP ? sizeof(zpx_webp_opts)
                                                    : sizeof(zpx_qoi_opts)))
    return ZPX_ERR_ARGUMENT;

  switch (format) {
  case ZPX_FMT_PNG: {
    zpx_png_opts dflt = {sizeof dflt, 6, NULL, 0, NULL, 0, -1};
    s = repack(src, width, height, stride, in_c, in_bits, 0, 0, 0, &tight,
               &c, &bits);
    if (s == ZPX_OK)
      s = zpx_int_encode_png(tight, width, height, c, bits,
                             opts ? (const zpx_png_opts *) opts : &dflt,
                             write, closure, &detail);
    break;
  }
  case ZPX_FMT_JPEG: {
    zpx_jpeg_opts dflt = {sizeof dflt, 90, 2, 0, NULL, 0, NULL, 0};
    s = repack(src, width, height, stride, in_c, in_bits, 1, 0, 1, &tight,
               &c, &bits);
    if (s == ZPX_OK)
      s = zpx_int_encode_jpeg(tight, width, height, c,
                              opts ? (const zpx_jpeg_opts *) opts : &dflt,
                              write, closure, &detail);
    break;
  }
  case ZPX_FMT_WEBP: {
    zpx_webp_opts dflt = {sizeof dflt, 75.0f, 0, 4, NULL, 0, NULL, 0};
    s = repack(src, width, height, stride, in_c, in_bits, 1, 1, 0, &tight,
               &c, &bits);
    if (s == ZPX_OK)
      s = zpx_int_encode_webp(tight, width, height, c,
                              opts ? (const zpx_webp_opts *) opts : &dflt,
                              write, closure, &detail);
    break;
  }
  case ZPX_FMT_QOI: {
    const zpx_qoi_opts *o = (const zpx_qoi_opts *) opts;
    if (in_bits != 8) return ZPX_ERR_ARGUMENT;
    s = repack(src, width, height, stride, in_c, in_bits, 0, 1, 0, &tight,
               &c, &bits);
    if (s == ZPX_OK)
      s = zpx_int_encode_qoi(tight, width, height, c,
                             o ? o->colourspace : 0, write, closure,
                             &detail);
    break;
  }
  default:
    return ZPX_ERR_FORMAT;
  }
  free(tight);
  return s;
}

static const zupix_api_v1 api_v1 = {
  ZUPIX_ABI_VERSION,
  (uint32_t) sizeof(zupix_api_v1),
  api_sniff,
  api_probe,
  api_decode,
  api_metadata,
  api_encode,
  zpx_status_string,
};

const zupix_api_v1 *zupix_get_api(uint32_t version) {
  return version == ZUPIX_ABI_VERSION ? &api_v1 : NULL;
}
