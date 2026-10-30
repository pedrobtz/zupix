/* Calls zupix only through the table zupix-r.h resolves, as any sibling
 * package would. */

#include <stdlib.h>
#include <string.h>

#include <zupix-r.h>

SEXP zt_table(void) {
  const zupix_api_v1 *api = zupix_api();
  SEXP out;
  if (api == NULL) return R_NilValue;
  out = PROTECT(Rf_allocVector(INTSXP, 2));
  INTEGER(out)[0] = (int) api->abi_version;
  INTEGER(out)[1] = (int) api->struct_size;
  UNPROTECT(1);
  return out;
}

/* Asks for an ABI version zupix does not speak: must get NULL. */
SEXP zt_future_abi(void) {
  union {
    DL_FUNC fn;
    const zupix_api_v1 *(*get)(uint32_t);
  } r;
  r.fn = R_GetCCallable("zupix", "zupix_get_api");
  return Rf_ScalarLogical(r.fn != NULL &&
                          r.get(ZUPIX_ABI_VERSION + 1u) == NULL &&
                          r.get(0u) == NULL);
}

SEXP zt_probe(SEXP x) {
  const zupix_api_v1 *api = zupix_api();
  zpx_info info;
  zpx_status s;
  SEXP out;
  memset(&info, 0, sizeof info);
  info.struct_size = (uint32_t) sizeof info;
  s = api->probe(RAW(x), (size_t) XLENGTH(x), NULL, &info);
  out = PROTECT(Rf_allocVector(INTSXP, 8));
  INTEGER(out)[0] = (int) s;
  INTEGER(out)[1] = (int) info.format;
  INTEGER(out)[2] = (int) info.width;
  INTEGER(out)[3] = (int) info.height;
  INTEGER(out)[4] = info.bits;
  INTEGER(out)[5] = info.channels;
  INTEGER(out)[6] = info.orientation;
  INTEGER(out)[7] = info.animated;
  UNPROTECT(1);
  return out;
}

/* Decodes into a raw vector of `height` rows padded to a stride 3 bytes
 * wider than needed, then returns the rows without the padding, or the
 * status as an integer. */
SEXP zt_decode(SEXP x, SEXP pixfmt_) {
  const zupix_api_v1 *api = zupix_api();
  zpx_pixfmt f = (zpx_pixfmt) Rf_asInteger(pixfmt_);
  size_t bpp = f == ZPX_PIX_RGBA8 ? 4 : f == ZPX_PIX_RGB8 ? 3
             : f == ZPX_PIX_Y8 ? 1 : f == ZPX_PIX_RGBA16 ? 8 : 2;
  zpx_info info;
  zpx_status s;
  size_t row, stride;
  SEXP padded, out;
  memset(&info, 0, sizeof info);
  info.struct_size = (uint32_t) sizeof info;
  s = api->probe(RAW(x), (size_t) XLENGTH(x), NULL, &info);
  if (s != ZPX_OK) return Rf_ScalarInteger((int) s);
  row = (size_t) info.width * bpp;
  stride = row + 3;
  padded = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (stride * info.height)));
  s = api->decode(RAW(x), (size_t) XLENGTH(x), NULL, f, RAW(padded), stride,
                  stride * info.height);
  if (s != ZPX_OK) {
    UNPROTECT(1);
    return Rf_ScalarInteger((int) s);
  }
  out = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (row * info.height)));
  for (uint32_t y = 0; y < info.height; y++)
    memcpy(RAW(out) + y * row, RAW(padded) + y * stride, row);
  UNPROTECT(2);
  return out;
}

SEXP zt_metadata(SEXP x, SEXP which) {
  const zupix_api_v1 *api = zupix_api();
  uint32_t fourcc = Rf_asInteger(which) == 1 ? ZPX_META_ICC : ZPX_META_EXIF;
  size_t n = 0;
  zpx_status s = api->metadata(RAW(x), (size_t) XLENGTH(x), fourcc, NULL, &n);
  SEXP out;
  if (s != ZPX_OK) return Rf_ScalarInteger((int) s);
  out = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) n));
  s = api->metadata(RAW(x), (size_t) XLENGTH(x), fourcc, RAW(out), &n);
  UNPROTECT(1);
  if (s != ZPX_OK) return Rf_ScalarInteger((int) s);
  return out;
}

typedef struct {
  uint8_t *data;
  size_t len, cap;
} grow;

static int grow_write(void *closure, const uint8_t *p, size_t n) {
  grow *g = (grow *) closure;
  if (g->len + n > g->cap) {
    size_t cap = g->cap ? 2 * g->cap : 4096;
    uint8_t *q;
    while (cap < g->len + n) cap *= 2;
    q = (uint8_t *) realloc(g->data, cap);
    if (q == NULL) return 1;
    g->data = q;
    g->cap = cap;
  }
  memcpy(g->data + g->len, p, n);
  g->len += n;
  return 0;
}

static int failing_write(void *closure, const uint8_t *p, size_t n) {
  (void) closure; (void) p; (void) n;
  return 1;
}

/* Encodes `pixels` (rows of width * bpp bytes, tight) with default
 * options; returns the file, or the status as an integer. */
SEXP zt_encode(SEXP pixels, SEXP format_, SEXP pixfmt_, SEXP w_, SEXP h_,
               SEXP fail_) {
  const zupix_api_v1 *api = zupix_api();
  zpx_pixfmt f = (zpx_pixfmt) Rf_asInteger(pixfmt_);
  uint32_t w = (uint32_t) Rf_asInteger(w_), h = (uint32_t) Rf_asInteger(h_);
  size_t bpp = f == ZPX_PIX_RGBA8 ? 4 : f == ZPX_PIX_RGB8 ? 3
             : f == ZPX_PIX_Y8 ? 1 : f == ZPX_PIX_RGBA16 ? 8 : 2;
  grow g = {NULL, 0, 0};
  zpx_status s;
  SEXP out;
  s = api->encode((zpx_format) Rf_asInteger(format_), f, RAW(pixels), w, h,
                  w * bpp, NULL, Rf_asLogical(fail_) ? failing_write
                                                     : grow_write, &g);
  if (s != ZPX_OK) {
    free(g.data);
    return Rf_ScalarInteger((int) s);
  }
  out = Rf_allocVector(RAWSXP, (R_xlen_t) g.len);
  memcpy(RAW(out), g.data, g.len);
  free(g.data);
  return out;
}

SEXP zt_status_string(SEXP s) {
  return Rf_mkString(zupix_api()->status_string((zpx_status) Rf_asInteger(s)));
}
