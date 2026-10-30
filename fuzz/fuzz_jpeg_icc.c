/* The JPEG marker walk and APP2 ICC reassembly: the input follows SOI, so
 * every mutation is a JPEG marker stream. */
#include <stdlib.h>
#include <string.h>

#include "fuzz.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  uint8_t *buf;
  if (size > (1u << 20)) return 0;
  buf = (uint8_t *) malloc(size + 2);
  if (buf == NULL) return 0;
  buf[0] = 0xff;
  buf[1] = 0xd8;
  memcpy(buf + 2, data, size);
  zpx_fuzz_scan(buf, size + 2);
  free(buf);
  return 0;
}
