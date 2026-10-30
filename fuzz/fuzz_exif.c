/* The EXIF IFD0 reader on its own: the input is a TIFF block. */
#include "fuzz.h"

static volatile int seen;

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  seen = zpx_int_exif_orientation(data, size);
  return 0;
}
