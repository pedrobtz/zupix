/* The one translation unit that compiles Wuffs's implementation. Only the
 * modules zupix decodes with are built (design §4.1): PNG, JPEG and WebP;
 * QOI decodes through qoi.h (zpx_qoi.c). Wuffs's functions stay
 * extern rather than static (WUFFS_CONFIG__STATIC_FUNCTIONS would leave the
 * unused ones as -Wunused-function warnings); $(C_VISIBILITY) keeps them out
 * of the shared object's exports. */

#define WUFFS_IMPLEMENTATION
#define WUFFS_CONFIG__MODULES
#define WUFFS_CONFIG__MODULE__BASE
#define WUFFS_CONFIG__MODULE__ADLER32
#define WUFFS_CONFIG__MODULE__CRC32
#define WUFFS_CONFIG__MODULE__DEFLATE
#define WUFFS_CONFIG__MODULE__ZLIB
#define WUFFS_CONFIG__MODULE__PNG
#define WUFFS_CONFIG__MODULE__JPEG
#define WUFFS_CONFIG__MODULE__VP8
#define WUFFS_CONFIG__MODULE__WEBP

#include "vendor/wuffs/wuffs-v0.4.c"

#include "zpx_int.h"

const char *zpx_int_wuffs_version(void) {
  return WUFFS_VERSION_STRING;
}

/* Whether this build compiled any of Wuffs's CPU-specific SIMD paths. */
int zpx_int_wuffs_simd(void) {
#if defined(WUFFS_PRIVATE_IMPL__CPU_ARCH__X86_64) || \
    defined(WUFFS_PRIVATE_IMPL__CPU_ARCH__ARM_NEON)
  return 1;
#else
  return 0;
#endif
}
