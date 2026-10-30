#include "src/webp/encode.h"

#include "zpx_int.h"

int zpx_int_webp_encoder_version(void) {
  return WebPGetEncoderVersion();
}
