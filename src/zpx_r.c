/* .Call glue: the only C that touches R objects (design §4). */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <stdio.h>
#include <zlib.h>

#include "zpx_int.h"
#include "zpx_r.h"

/* The versions compiled into this build, for zupix_info(). */
SEXP zpx_r_versions(void) {
  const char *names[] = {"wuffs", "libjpeg-turbo", "libwebp", "zlib", ""};
  int webp = zpx_int_webp_encoder_version();
  char webp_version[32];
  snprintf(webp_version, sizeof webp_version, "%d.%d.%d",
           (webp >> 16) & 0xff, (webp >> 8) & 0xff, webp & 0xff);

  SEXP out = PROTECT(Rf_mkNamed(STRSXP, names));
  SET_STRING_ELT(out, 0, Rf_mkChar(zpx_int_wuffs_version()));
  SET_STRING_ELT(out, 1, Rf_mkChar(zpx_int_jpeg_version()));
  SET_STRING_ELT(out, 2, Rf_mkChar(webp_version));
  SET_STRING_ELT(out, 3, Rf_mkChar(zlibVersion()));
  UNPROTECT(1);
  return out;
}

SEXP zpx_r_wuffs_simd(void) {
  return Rf_ScalarLogical(zpx_int_wuffs_simd());
}

/* ---- decoding --------------------------------------------------------- */

#include <Rconfig.h>
#include <string.h>

#include "zpx_core.h"

/* What the R layer turns into a classed condition (R/conditions.R):
 * list(status, detail, limit, value, cap). */
static SEXP failure(zpx_status s, const char *detail, zpx_limit_kind lim,
                    double value, double cap) {
  const char *names[] = {"status", "detail", "limit", "value", "cap", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_ScalarInteger((int) s));
  SET_VECTOR_ELT(out, 1, Rf_mkString(detail ? detail : zpx_status_string(s)));
  SET_VECTOR_ELT(out, 2, Rf_ScalarInteger((int) lim));
  SET_VECTOR_ELT(out, 3, Rf_ScalarReal(value));
  SET_VECTOR_ELT(out, 4, Rf_ScalarReal(cap));
  Rf_setAttrib(out, R_ClassSymbol, Rf_mkString("zupix_failure"));
  UNPROTECT(1);
  return out;
}

static void read_limits(SEXP limits, zpx_limits *l) {
  const double *v = REAL(limits);
  l->struct_size = (uint32_t) sizeof *l;
  l->max_side = (uint32_t) v[0];
  l->max_pixels = (uint64_t) v[1];
  l->max_bytes = (uint64_t) v[2];
  l->max_metadata = (uint64_t) v[3];
}

SEXP zpx_r_sniff(SEXP x) {
  return Rf_ScalarInteger((int) zpx_sniff(RAW(x), (size_t) XLENGTH(x)));
}

/* a * b, or UINT64_MAX when it overflows. */
static uint64_t mul64(uint64_t a, uint64_t b) {
  if (a != 0 && b > UINT64_MAX / a) return UINT64_MAX;
  return a * b;
}

static uint64_t add64(uint64_t a, uint64_t b) {
  return b > UINT64_MAX - a ? UINT64_MAX : a + b;
}

/* One sample of the decoded RGBA intermediate (row-major, four samples per
 * pixel; RGBA8 bytes, or BGRA 16-bit little-endian as Wuffs writes it). */
static unsigned sample(const uint8_t *px, int wide, int c) {
  if (!wide) return px[c];
  /* BGRA order: R is sample 2, G 1, B 0, A 3. */
  static const int map[4] = {2, 1, 0, 3};
  const uint8_t *p = px + 2 * map[c];
  return (unsigned) p[0] | ((unsigned) p[1] << 8);
}

/* 16 to 8 bits, rounding to nearest: round(v / 257). */
static unsigned to8(unsigned v) {
  return (v + 128u) / 257u;
}

/* Which intermediate sample feeds each output channel. The intermediate is
 * RGBA even for grey sources, whose R, G and B are equal, so taking R for
 * grey and A for alpha is exact (channels are never removed, design D10). */
static int source_channel(int out_channels, int c) {
  static const int one[1] = {0}, two[2] = {0, 3};
  if (out_channels == 1) return one[c];
  if (out_channels == 2) return two[c];
  return c;
}

/* as: 1 "native", 2 "double", 3 "integer". bits and channels are NULL or
 * an integer; format is 0 for "auto" or a zpx_format. Returns
 * list(pixels, width, height, channels, bits) or a zupix_failure. */
SEXP zpx_r_read(SEXP x, SEXP as_, SEXP bits_, SEXP channels_, SEXP format_,
                SEXP limits_) {
  const uint8_t *buf = RAW(x);
  size_t len = (size_t) XLENGTH(x);
  int as = Rf_asInteger(as_);
  int want_format = Rf_asInteger(format_);
  zpx_limits lim;
  zpx_int_probe p;
  zpx_status s;
  zpx_format found;
  int bits, channels, wide, direct;
  uint64_t pixels, result_bytes, inter_bytes, total;
  R_xlen_t n;
  SEXP pixels_sexp, inter = R_NilValue, out;
  uint8_t *inter_buf;
  size_t stride;

  read_limits(limits_, &lim);

  found = zpx_sniff(buf, len);
  if (found == ZPX_FMT_UNKNOWN)
    return failure(ZPX_ERR_FORMAT, "not a PNG, JPEG, WebP or QOI signature",
                   ZPX_LIMIT_NONE, 0, 0);
  if (want_format != 0 && want_format != (int) found)
    return failure(ZPX_ERR_FORMAT, "`format` disagrees with the signature",
                   ZPX_LIMIT_NONE, (double) found, (double) want_format);

  s = zpx_int_probe_image(buf, len, &lim, &p);
  if (s != ZPX_OK)
    return failure(s, p.detail, p.limit, (double) p.limit_value,
                   (double) p.limit_cap);

  if (as == 1) {
    if (!Rf_isNull(bits_) && Rf_asInteger(bits_) != 8)
      return failure(ZPX_ERR_ARGUMENT,
                     "as = \"native\" is 8-bit; `bits` must be NULL or 8",
                     ZPX_LIMIT_NONE, 0, 0);
    if (!Rf_isNull(channels_) && Rf_asInteger(channels_) != 4)
      return failure(ZPX_ERR_ARGUMENT,
                     "as = \"native\" is RGBA; `channels` must be NULL or 4",
                     ZPX_LIMIT_NONE, 0, 0);
    bits = 8;
    channels = 4;
  } else {
    bits = Rf_isNull(bits_) ? p.bits : Rf_asInteger(bits_);
    channels = Rf_isNull(channels_) ? p.channels : Rf_asInteger(channels_);
    if (channels < p.channels)
      return failure(ZPX_ERR_ARGUMENT,
                     "`channels` would remove channels the image has",
                     ZPX_LIMIT_NONE, (double) channels, (double) p.channels);
  }

  wide = p.bits == 16;
  pixels = (uint64_t) p.width * (uint64_t) p.height;
#ifdef WORDS_BIGENDIAN
  direct = 0;
#else
  /* A little-endian nativeRaster is RGBA bytes: decode into it in place. */
  direct = as == 1 && !wide;
#endif
  result_bytes = mul64(pixels, as == 1 ? 4 : (uint64_t) channels *
                                             (as == 2 ? 8 : 4));
  inter_bytes = direct ? 0 : mul64(pixels, wide ? 8 : 4);
  total = add64(add64(result_bytes, inter_bytes), p.workbuf_len);
  if (total > lim.max_bytes)
    return failure(ZPX_ERR_LIMIT, NULL, ZPX_LIMIT_BYTES, (double) total,
                   (double) lim.max_bytes);

  n = (R_xlen_t) (as == 1 ? pixels : pixels * (uint64_t) channels);
  pixels_sexp = PROTECT(Rf_allocVector(as == 2 ? REALSXP : INTSXP, n));
  if (direct) {
    inter_buf = (uint8_t *) INTEGER(pixels_sexp);
  } else {
    inter = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) inter_bytes));
    inter_buf = RAW(inter);
  }
  stride = (size_t) p.width * (wide ? 8 : 4);
  s = zpx_int_decode_image(buf, len, &lim, wide ? ZPX_PIX_RGBA16 : ZPX_PIX_RGBA8,
                           inter_buf, stride, stride * (size_t) p.height, &p);
  if (s != ZPX_OK) {
    UNPROTECT(direct ? 1 : 2);
    return failure(s, p.detail, p.limit, (double) p.limit_value,
                   (double) p.limit_cap);
  }

  if (!direct) {
    size_t w = p.width, h = p.height, bpp = wide ? 8 : 4;
    if (as == 1) {
      int *dst = INTEGER(pixels_sexp);
      for (size_t i = 0; i < w * h; i++) {
        const uint8_t *px = inter_buf + i * bpp;
        unsigned r = sample(px, wide, 0), g = sample(px, wide, 1),
                 b = sample(px, wide, 2), a = sample(px, wide, 3);
        if (wide) { r = to8(r); g = to8(g); b = to8(b); a = to8(a); }
        dst[i] = (int) (r | (g << 8) | (b << 16) | (a << 24));
      }
    } else {
      /* Row-major interleaved to R's column-major height x width x
       * channels; depth converted to `bits`. */
      int down = wide && bits == 8, up = !wide && bits == 16;
      double scale = bits == 16 ? 65535.0 : 255.0;
      for (int c = 0; c < channels; c++) {
        int sc = source_channel(channels, c);
        for (size_t x0 = 0; x0 < w; x0++) {
          for (size_t y = 0; y < h; y++) {
            const uint8_t *px = inter_buf + (y * w + x0) * bpp;
            unsigned v = sample(px, wide, sc);
            R_xlen_t k = (R_xlen_t) (y + x0 * h + (size_t) c * w * h);
            if (down) v = to8(v);
            else if (up) v *= 257u;
            if (as == 2) REAL(pixels_sexp)[k] = v / scale;
            else INTEGER(pixels_sexp)[k] = (int) v;
          }
        }
      }
    }
  }

  {
    const char *names[] = {"pixels", "width", "height", "channels", "bits",
                           ""};
    out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, pixels_sexp);
    SET_VECTOR_ELT(out, 1, Rf_ScalarInteger((int) p.width));
    SET_VECTOR_ELT(out, 2, Rf_ScalarInteger((int) p.height));
    SET_VECTOR_ELT(out, 3, Rf_ScalarInteger(channels));
    SET_VECTOR_ELT(out, 4, Rf_ScalarInteger(bits));
  }
  UNPROTECT(direct ? 2 : 3);
  return out;
}
