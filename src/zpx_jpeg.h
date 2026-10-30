#ifndef ZPX_JPEG_H
#define ZPX_JPEG_H

#include <setjmp.h>
#include <stdio.h>

#include "jpeglib.h"

/* What an encoder hangs on cinfo->client_data: the frame libjpeg-turbo's
 * error exit unwinds to, and the message it formatted. */
typedef struct {
  jmp_buf env;
  char message[JMSG_LENGTH_MAX];
} zpx_jpeg_jmp;

void zpx_int_jpeg_error_exit(j_common_ptr cinfo);

#endif
