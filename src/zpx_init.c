#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zpx_r.h"
#include "zpx_table.h"

static const R_CallMethodDef call_methods[] = {
  {"zpx_r_versions", (DL_FUNC) &zpx_r_versions, 0},
  {"zpx_r_wuffs_simd", (DL_FUNC) &zpx_r_wuffs_simd, 0},
  {"zpx_r_sniff", (DL_FUNC) &zpx_r_sniff, 1},
  {"zpx_r_read", (DL_FUNC) &zpx_r_read, 6},
  {"zpx_r_info", (DL_FUNC) &zpx_r_info, 2},
  {"zpx_r_icc", (DL_FUNC) &zpx_r_icc, 2},
  {"zpx_r_exif", (DL_FUNC) &zpx_r_exif, 2},
  {"zpx_r_encode", (DL_FUNC) &zpx_r_encode, 7},
  {NULL, NULL, 0}
};

/* The only symbol the shared object exports: everything else is reached
 * through a registration table, .Call entry points through
 * R_registerRoutines() and the C table (design §7) through
 * R_RegisterCCallable(). */
void attribute_visible R_init_zupix(DllInfo *dll) {
  /* A function pointer converted through a union rather than a cast, which
   * -Wcast-function-type-mismatch reports. */
  union {
    const zupix_api_v1 *(*get)(uint32_t);
    DL_FUNC fn;
  } api;
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  api.get = zupix_get_api;
  R_RegisterCCallable("zupix", "zupix_get_api", api.fn);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
