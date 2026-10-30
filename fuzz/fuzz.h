/* Shared by the fuzz targets (design §9). They link the R-free core
 * directly: no R, so libFuzzer and the sanitizers see every allocation. */
#ifndef ZPX_FUZZ_H
#define ZPX_FUZZ_H

#include <stddef.h>
#include <stdint.h>

#include "zpx_core.h"

/* A 16 MiB pixel cap, as zukomp caps output: findings are then memory
 * safety, not decompression bombs the limits already refuse by design. */
void zpx_fuzz_limits(zpx_limits *l);

/* Probe and, within the cap, decode at the image's depth; touches every
 * byte of the result so an uninitialised read would show. */
void zpx_fuzz_decode(const uint8_t *data, size_t size);

/* Scan and extract the ICC profile and EXIF orientation. */
void zpx_fuzz_scan(const uint8_t *data, size_t size);

#endif
