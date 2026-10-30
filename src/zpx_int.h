#ifndef ZPX_INT_H
#define ZPX_INT_H

/* Internal declarations shared by the core (zpx_*.c). No R header: the
 * core builds without R so that fuzz targets and the C table can use it. */

/* zpx_wuffs.c */
const char *zpx_int_wuffs_version(void);
int zpx_int_wuffs_simd(void);

/* zpx_jpeg_error.c */
const char *zpx_int_jpeg_version(void);

/* zpx_webp.c */
int zpx_int_webp_encoder_version(void);

#endif
