#include <string.h>

#include "zpx_core.h"

static uint32_t be32(const uint8_t *p) {
  return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16) |
         ((uint32_t) p[2] << 8) | (uint32_t) p[3];
}

/* The IHDR fields, and whether tRNS appears before the first IDAT: what
 * the channel count of design §6.2 needs, which Wuffs's reported pixel
 * format cannot tell apart for 16-bit images. One bounded pass, no
 * recursion; each step consumes at least the 12 bytes of a chunk's frame.
 * CRCs are left to Wuffs, which checks them while decoding; Stage 3's
 * scanner checks them on the metadata it reads. */
zpx_status zpx_int_png_header(const uint8_t *buf, size_t len,
                              zpx_png_header *out, const char **detail) {
  size_t pos = 8;
  int first = 1;

  memset(out, 0, sizeof *out);
  if (len < 8 || zpx_sniff(buf, len) != ZPX_FMT_PNG) {
    *detail = "not a PNG signature";
    return ZPX_ERR_FORMAT;
  }
  for (;;) {
    uint32_t chunk_len;
    const uint8_t *type;
    if (len - pos < 12) {
      *detail = "PNG ends before its first IDAT chunk";
      return ZPX_ERR_DECODE;
    }
    chunk_len = be32(buf + pos);
    type = buf + pos + 4;
    if (chunk_len > 0x7fffffffu || (size_t) chunk_len > len - pos - 12) {
      *detail = "PNG chunk length runs past the end of the input";
      return ZPX_ERR_DECODE;
    }
    if (first) {
      const uint8_t *d = buf + pos + 8;
      if (memcmp(type, "IHDR", 4) != 0 || chunk_len != 13) {
        *detail = "PNG does not start with a 13-byte IHDR chunk";
        return ZPX_ERR_DECODE;
      }
      out->width = be32(d);
      out->height = be32(d + 4);
      out->depth = d[8];
      out->colour_type = d[9];
      out->interlace = d[12];
      first = 0;
    } else if (memcmp(type, "tRNS", 4) == 0) {
      out->has_trns = 1;
    } else if (memcmp(type, "IDAT", 4) == 0) {
      return ZPX_OK;
    }
    pos += 12 + (size_t) chunk_len;
  }
}
