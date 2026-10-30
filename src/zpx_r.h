#ifndef ZPX_R_H
#define ZPX_R_H

#define R_NO_REMAP
#include <Rinternals.h>

SEXP zpx_r_versions(void);
SEXP zpx_r_wuffs_simd(void);
SEXP zpx_r_sniff(SEXP x);
SEXP zpx_r_read(SEXP x, SEXP as_, SEXP bits_, SEXP channels_, SEXP format_,
                SEXP limits_);

#endif
