#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zpx_r.h"

static const R_CallMethodDef call_methods[] = {
  {"zpx_r_versions", (DL_FUNC) &zpx_r_versions, 0},
  {"zpx_r_wuffs_simd", (DL_FUNC) &zpx_r_wuffs_simd, 0},
  {NULL, NULL, 0}
};

/* The only symbol the shared object exports: everything else is reached
 * through the registration table (design §3). */
void attribute_visible R_init_zupix(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
