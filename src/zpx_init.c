#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

static const R_CallMethodDef call_methods[] = {
  {NULL, NULL, 0}
};

/* The only symbol the shared object exports: everything else is reached
 * through the registration table (design §3, test-abi.R from Stage 6). */
void attribute_visible R_init_zupix(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
