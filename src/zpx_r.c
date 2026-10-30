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
