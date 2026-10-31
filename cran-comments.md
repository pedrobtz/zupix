## Submission

This is a new submission.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

`R CMD check --as-cran` through the pedrobtz/r-actions GitHub Actions
workflows:

* macOS (latest), R release
* Windows (latest), R release and R-devel
* Ubuntu (latest), R release and R oldrel-1
* r-devel containers: clang 23, Ubuntu clang, Ubuntu GCC 16
* r-devel without Suggests installed (NOSUGGESTS) and without long doubles
  (NOLD)

The compiled code is also checked with AddressSanitizer and
UndefinedBehaviorSanitizer, valgrind, rchk, LTO and gctorture.

## Bundled code

zupix bundles Wuffs, the compression half of libjpeg-turbo, the libwebp
encoder and qoi.h, so it needs no system image library. Their authors are
listed in `Authors@R` and their licences in `inst/COPYRIGHTS` and
`inst/licenses/`. Local patches remove every use of `stdout`, `stderr`,
`exit()` and `abort()`; zlib is linked from R's own toolchain.

## Method references

There are no published references describing the methods in this package.
It implements the published file format specifications for PNG, JPEG, WebP
and QOI through the bundled libraries.
