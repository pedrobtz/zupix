/* jconfig.h for the libjpeg-turbo 3.2.1 compression subset in zupix.
 *
 * Hand-written in place of the file CMake generates from src/jconfig.h.in,
 * which zupix does not run. Arithmetic coding is off (design D2) and there
 * is no SIMD (D15). tools/vendor/verify checks LIBJPEG_TURBO_VERSION
 * against tools/vendor/manifest.tsv.
 */

#define JPEG_LIB_VERSION  62
#define LIBJPEG_TURBO_VERSION  3.2.1
#define LIBJPEG_TURBO_VERSION_NUMBER  3002001

#define MEM_SRCDST_SUPPORTED  1

#ifndef BITS_IN_JSAMPLE
#define BITS_IN_JSAMPLE  8
#endif

#ifdef _WIN32

#undef RIGHT_SHIFT_IS_UNSIGNED

#ifndef __RPCNDR_H__
typedef unsigned char boolean;
#endif
#define HAVE_BOOLEAN

#if !(defined(_BASETSD_H_) || defined(_BASETSD_H))
typedef short INT16;
typedef signed int INT32;
#endif
#define XMD_H

#endif
