/* Decodes QOI through Wuffs under the fuzz pixel cap. Other inputs are
 * ignored, so the corpus stays QOI; seeds are real files. */
#include "fuzz.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (zpx_sniff(data, size) != ZPX_FMT_QOI) return 0;
  zpx_fuzz_decode(data, size);
  return 0;
}
