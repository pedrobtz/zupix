/* zupix-r.h: resolves zupix's C table from an R package (design §7).
 *
 * Include this, not zupix.h, from a package's C code. zupix_api() looks the
 * table up once per translation unit through R_GetCCallable() and caches
 * it; it returns NULL when zupix speaks a different ABI version, so a
 * consumer built against an older zupix fails cleanly rather than calling
 * through a mismatched table. */

#ifndef ZUPIX_R_H
#define ZUPIX_R_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include "zupix.h"

#ifdef __cplusplus
extern "C" {
#endif

/* static inline, so a translation unit that includes this header without
 * calling it gets no unused-function warning. */
static inline const zupix_api_v1 *zupix_api(void) {
  static const zupix_api_v1 *cached = NULL;
  if (cached == NULL) {
    /* R_GetCCallable() returns DL_FUNC; casting that straight to the real
     * signature trips -Wcast-function-type-mismatch in a consumer built
     * with strict flags, so the conversion goes through a union. */
    union {
      DL_FUNC fn;
      const zupix_api_v1 *(*get)(uint32_t);
    } resolve;
    resolve.fn = R_GetCCallable("zupix", "zupix_get_api");
    if (resolve.fn != NULL) {
      cached = resolve.get((uint32_t) ZUPIX_ABI_VERSION);
    }
  }
  return cached;
}

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* ZUPIX_R_H */
