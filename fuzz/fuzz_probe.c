/* zupix's own container scanners over arbitrary bytes: the package's only
 * hand-written parsers of untrusted input (design D12). */
#include "fuzz.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  zpx_fuzz_scan(data, size);
  return 0;
}
