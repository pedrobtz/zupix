#include <stdlib.h>
#include <string.h>

#include "fuzz.h"

void zpx_fuzz_limits(zpx_limits *l) {
  l->struct_size = (uint32_t) sizeof *l;
  l->max_side = 65535u;
  l->max_pixels = 4u << 20;
  l->max_bytes = 16u << 20;
  l->max_metadata = 1u << 20;
}

static volatile unsigned sink_byte;

void zpx_fuzz_decode(const uint8_t *data, size_t size) {
  zpx_limits l;
  zpx_int_probe p;
  size_t bpp, stride, n;
  uint8_t *dst;
  zpx_fuzz_limits(&l);
  if (zpx_int_probe_image(data, size, &l, &p) != ZPX_OK) return;
  bpp = p.bits == 16 ? 8 : 4;
  stride = (size_t) p.width * bpp;
  n = stride * p.height;
  if (n == 0 || n > l.max_bytes) return;
  dst = (uint8_t *) malloc(n);
  if (dst == NULL) return;
  if (zpx_int_decode_image(data, size, &l,
                           p.bits == 16 ? ZPX_PIX_RGBA16 : ZPX_PIX_RGBA8, dst,
                           stride, n, &p) == ZPX_OK) {
    unsigned acc = 0;
    for (size_t i = 0; i < n; i++) acc += dst[i];
    sink_byte = acc;
  }
  free(dst);
}

void zpx_fuzz_scan(const uint8_t *data, size_t size) {
  zpx_limits l;
  zpx_meta m;
  const char *detail = NULL;
  size_t need = 0;
  zpx_fuzz_limits(&l);
  if (zpx_int_scan(data, size, &l, &m, &detail) != ZPX_OK) return;
  if (m.icc_len > 0 &&
      zpx_int_icc(data, size, &m, &l, NULL, &need, &detail) == ZPX_OK &&
      need > 0) {
    uint8_t *buf = (uint8_t *) malloc(need);
    size_t cap = need;
    if (buf != NULL) {
      zpx_int_icc(data, size, &m, &l, buf, &cap, &detail);
      free(buf);
    }
  }
  if (m.exif_len > 0)
    sink_byte = (unsigned) zpx_int_exif_orientation(data + m.exif_off,
                                                     m.exif_len);
}
