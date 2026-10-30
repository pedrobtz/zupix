/* The one translation unit that compiles qoi.h's implementation. zupix
 * uses only qoi_encode(); QOI decoding goes through Wuffs (design D1), so
 * qoi_decode() is compiled but never called. */

#define QOI_IMPLEMENTATION
#define QOI_NO_STDIO
#include "vendor/qoi/qoi.h"
