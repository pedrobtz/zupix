/* Deliberately broken: an input starting "ZUPIX" overreads a heap buffer.
 * run.sh requires this target to crash before trusting the others, so a
 * green run means a crash would have been seen. */
#include <stdlib.h>
#include <string.h>

#include "fuzz.h"

static volatile uint8_t seen;

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size >= 5 && memcmp(data, "ZUPIX", 5) == 0) {
    uint8_t *b = (uint8_t *) malloc(4);
    if (b == NULL) return 0;
    seen = b[size]; /* out of bounds on purpose */
    free(b);
  }
  return 0;
}
