/* Encode then decode a fuzzer-chosen small image: PNG at its depth and
 * channel count, QOI at 8 bits with 3 or 4 channels. A mismatch is a bug,
 * reported by trapping. Input: width-1, height-1, channels-1 and a depth
 * flag in the first four bytes, then samples, repeated as needed. */
#include <stdlib.h>
#include <string.h>

#include "fuzz.h"

static void check(int ok) {
  if (!ok) __builtin_trap();
}

/* Decode `file` to RGBA at `bits` and compare with `src` widened the way
 * zupix widens (grey to RGB, opaque alpha). */
static void roundtrip(const uint8_t *file, size_t len, const uint8_t *src,
                      uint32_t w, uint32_t h, int c, int bits) {
  zpx_limits l;
  zpx_int_probe p;
  size_t bpp = bits == 16 ? 8 : 4, stride = (size_t) w * bpp;
  uint8_t *dst = (uint8_t *) malloc(stride * h);
  zpx_fuzz_limits(&l);
  check(dst != NULL);
  check(zpx_int_decode_image(file, len, &l,
                             bits == 16 ? ZPX_PIX_RGBA16 : ZPX_PIX_RGBA8, dst,
                             stride, stride * h, &p) == ZPX_OK);
  check(p.width == w && p.height == h);
  for (size_t i = 0; i < (size_t) w * h; i++) {
    for (int k = 0; k < 4; k++) {
      unsigned want, got;
      int from = c >= 3 ? (k < c ? k : -1) : (k < 3 ? 0 : (c == 2 ? 1 : -1));
      if (bits == 8) {
        want = from < 0 ? 255u : src[i * c + from];
        got = dst[i * 4 + k];
      } else {
        static const int bgra[4] = {2, 1, 0, 3};
        uint16_t u = 0xffff;
        if (from >= 0) memcpy(&u, src + 2 * (i * c + from), 2);
        want = u;
        got = (unsigned) dst[i * 8 + 2 * bgra[k]] |
              ((unsigned) dst[i * 8 + 2 * bgra[k] + 1] << 8);
      }
      check(want == got);
    }
  }
  free(dst);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  uint32_t w, h;
  int c, bits;
  size_t n;
  uint8_t *src;
  zpx_buffer out = {NULL, 0, 0};
  const char *detail = NULL;
  zpx_png_opts o = {sizeof o, 1, NULL, 0, NULL, 0, -1};
  if (size < 5) return 0;
  w = (uint32_t) (data[0] % 64) + 1;
  h = (uint32_t) (data[1] % 64) + 1;
  c = data[2] % 4 + 1;
  bits = data[3] & 1 ? 16 : 8;
  o.compression = data[3] >> 4 & 7;
  data += 4;
  size -= 4;
  n = (size_t) w * h * (size_t) c * (size_t) (bits / 8);
  src = (uint8_t *) malloc(n);
  if (src == NULL) return 0;
  for (size_t i = 0; i < n; i++) src[i] = data[i % size];

  check(zpx_int_encode_png(src, w, h, c, bits, &o, zpx_int_buffer_write, &out,
                           &detail) == ZPX_OK);
  roundtrip(out.data, out.len, src, w, h, c, bits);
  free(out.data);

  if (bits == 8 && c >= 3) {
    zpx_buffer q = {NULL, 0, 0};
    check(zpx_int_encode_qoi(src, w, h, c, 0, zpx_int_buffer_write, &q,
                             &detail) == ZPX_OK);
    roundtrip(q.data, q.len, src, w, h, c, 8);
    free(q.data);
  }
  free(src);
  return 0;
}
