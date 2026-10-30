#ifndef ZPX_TABLE_H
#define ZPX_TABLE_H

#include "zupix.h"

/* The table for ABI `version`, or NULL for any other version. Registered
 * with R_RegisterCCallable() as "zupix_get_api". */
const zupix_api_v1 *zupix_get_api(uint32_t version);

#endif
