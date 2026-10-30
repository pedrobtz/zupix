#ifndef ZPX_CORE_H
#define ZPX_CORE_H

/* The core's types and entry points: C99, no R header. The public parts
 * become inst/include/zupix.h with the C table (design §7, Stage 6). */

#include <stddef.h>
#include <stdint.h>

typedef enum {
  ZPX_OK = 0,
  ZPX_ERR_FORMAT,
  ZPX_ERR_DECODE,
  ZPX_ERR_UNSUPPORTED,
  ZPX_ERR_LIMIT,
  ZPX_ERR_MEMORY,
  ZPX_ERR_ARGUMENT,
  ZPX_ERR_ENCODE,
  ZPX_ERR_SINK
} zpx_status;

typedef enum {
  ZPX_FMT_UNKNOWN = 0,
  ZPX_FMT_PNG,
  ZPX_FMT_JPEG,
  ZPX_FMT_WEBP,
  ZPX_FMT_QOI
} zpx_format;

/* Interleaved destination formats. RGBA16 is four native-endian uint16_t
 * per pixel. */
typedef enum {
  ZPX_PIX_RGBA8 = 1,
  ZPX_PIX_RGB8,
  ZPX_PIX_Y8,
  ZPX_PIX_RGBA16,
  ZPX_PIX_Y16
} zpx_pixfmt;

typedef struct {
  uint32_t struct_size, max_side;
  uint64_t max_pixels, max_bytes, max_metadata;
} zpx_limits;

/* Which limit a ZPX_ERR_LIMIT tripped, the value seen and the cap. */
typedef enum {
  ZPX_LIMIT_NONE = 0,
  ZPX_LIMIT_SIDE,
  ZPX_LIMIT_PIXELS,
  ZPX_LIMIT_BYTES,
  ZPX_LIMIT_METADATA
} zpx_limit_kind;

/* What probing an image found, and why it failed when it did. `detail` is
 * a static string (an upstream status message or zupix's own) or NULL. */
typedef struct {
  zpx_format format;
  uint32_t width, height;
  uint8_t bits;      /* stored sample depth after expansion: 8 or 16 */
  uint8_t channels;  /* 1 grey, 2 grey and alpha, 3 RGB, 4 RGBA */
  uint64_t workbuf_len;
  zpx_limit_kind limit;
  uint64_t limit_value, limit_cap;
  const char *detail;
} zpx_int_probe;

zpx_format zpx_sniff(const uint8_t *buf, size_t len);
const char *zpx_status_string(zpx_status s);

/* Parses the header and checks max_side and max_pixels; allocates nothing
 * beyond the decoder's own state, which it frees before returning. */
zpx_status zpx_int_probe_image(const uint8_t *buf, size_t len,
                               const zpx_limits *limits, zpx_int_probe *out);

/* Decodes the first frame into dst, which holds `height` rows of `stride`
 * bytes. pixfmt is ZPX_PIX_RGBA8 or ZPX_PIX_RGBA16. Probes again, so a
 * caller that skips zpx_int_probe_image() is still held to the limits. */
zpx_status zpx_int_decode_image(const uint8_t *buf, size_t len,
                                const zpx_limits *limits, zpx_pixfmt pixfmt,
                                uint8_t *dst, size_t stride, size_t dst_len,
                                zpx_int_probe *out);

/* zpx_png.c: the IHDR fields and whether a tRNS chunk precedes IDAT. */
typedef struct {
  uint32_t width, height;
  uint8_t depth, colour_type, interlace;
  int has_trns;
} zpx_png_header;

zpx_status zpx_int_png_header(const uint8_t *buf, size_t len,
                              zpx_png_header *out, const char **detail);

#endif
