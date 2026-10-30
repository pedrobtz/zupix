/* jconfigint.h for the libjpeg-turbo 3.2.1 compression subset in zupix.
 *
 * Hand-written in place of the file CMake generates from
 * src/jconfigint.h.in. Every value CMake would probe is fixed here for the
 * compilers R supports (GCC and clang, including Rtools on Windows).
 */

#define BUILD  "zupix"

#if defined(__GNUC__) && !defined(_WIN32)
#define HIDDEN  __attribute__((visibility("hidden")))
#else
#define HIDDEN
#endif

#undef inline
#define INLINE  __inline__ __attribute__((always_inline))

#define THREAD_LOCAL

#define PACKAGE_NAME  "libjpeg-turbo"
#define VERSION  "3.2.1"

#if defined(__SIZEOF_SIZE_T__)
#define SIZEOF_SIZE_T  __SIZEOF_SIZE_T__
#else
#error "zupix: SIZEOF_SIZE_T cannot be determined"
#endif

/* __builtin_ctzl takes an unsigned long, which is 32 bits on 64-bit
 * Windows; libjpeg-turbo's portable fallback is used there instead. */
#if defined(__GNUC__) && !defined(_WIN32)
#define HAVE_BUILTIN_CTZL
#endif

#if defined(__has_attribute)
#if __has_attribute(fallthrough)
#define FALLTHROUGH  __attribute__((fallthrough));
#else
#define FALLTHROUGH
#endif
#else
#define FALLTHROUGH
#endif

#ifndef BITS_IN_JSAMPLE
#define BITS_IN_JSAMPLE  8
#endif

#undef C_ARITH_CODING_SUPPORTED
#undef D_ARITH_CODING_SUPPORTED
#undef WITH_SIMD
