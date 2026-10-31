/* libjpeg-turbo's error exit, reached through the patched jerror.c
 * (tools/patches/libjpeg-turbo/0001-no-stdio-or-exit.patch). Every zupix
 * encoder points cinfo->client_data at a zpx_jpeg_jmp and setjmp()s it
 * before calling into libjpeg, so the longjmp below lands in zupix's own
 * frame and never crosses R. */

#include <setjmp.h>
#include <stdio.h>

#include "jpeglib.h"

#include "zpx_int.h"
#include "zpx_jpeg.h"

#define ZPX_STR2(x) #x
#define ZPX_STR(x) ZPX_STR2(x)

void zpx_int_jpeg_error_exit(j_common_ptr cinfo) {
  zpx_jpeg_jmp *j = (zpx_jpeg_jmp *) cinfo->client_data;
  j->code = cinfo->err->msg_code;
  longjmp(j->env, 1);
}

const char *zpx_int_jpeg_version(void) {
  return ZPX_STR(LIBJPEG_TURBO_VERSION);
}
