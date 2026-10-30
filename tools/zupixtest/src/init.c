#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

SEXP zt_table(void);
SEXP zt_future_abi(void);
SEXP zt_probe(SEXP);
SEXP zt_decode(SEXP, SEXP);
SEXP zt_metadata(SEXP, SEXP);
SEXP zt_encode(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
SEXP zt_status_string(SEXP);

static const R_CallMethodDef calls[] = {
  {"zt_table", (DL_FUNC) &zt_table, 0},
  {"zt_future_abi", (DL_FUNC) &zt_future_abi, 0},
  {"zt_probe", (DL_FUNC) &zt_probe, 1},
  {"zt_decode", (DL_FUNC) &zt_decode, 2},
  {"zt_metadata", (DL_FUNC) &zt_metadata, 2},
  {"zt_encode", (DL_FUNC) &zt_encode, 6},
  {"zt_status_string", (DL_FUNC) &zt_status_string, 1},
  {NULL, NULL, 0}
};

void R_init_zupixtest(DllInfo *dll) {
  R_registerRoutines(dll, NULL, calls, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
