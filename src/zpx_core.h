#ifndef ZPX_CORE_H
#define ZPX_CORE_H

/* The core's internal types and entry points: C99, no R header. The C
 * table over them is zpx_table.c (design §7). */

#include <stddef.h>
#include <stdint.h>

/* The public types: status, format, pixel layouts, limits, the write
 * callback and the encoder options (inst/include/zupix.h). */
#include "zupix.h"

/* Which limit a ZPX_ERR_LIMIT tripped, the value seen and the cap. */
typedef enum {
  ZPX_LIMIT_NONE = 0,
  ZPX_LIMIT_SIDE,
  ZPX_LIMIT_PIXELS,
  ZPX_LIMIT_BYTES,
  ZPX_LIMIT_METADATA
} zpx_limit_kind;

zpx_format zpx_sniff(const uint8_t *buf, size_t len);
const char *zpx_status_string(zpx_status s);

/* zpx_scan.c: what zupix's own container scanners read (design §6.4).
 * Offsets point into the caller's buffer; ICC split over JPEG APP2
 * segments is reassembled by zpx_int_icc(). */
typedef enum {
  ZPX_CT_UNKNOWN = 0,
  ZPX_CT_GREY,
  ZPX_CT_GREY_ALPHA,
  ZPX_CT_RGB,
  ZPX_CT_RGBA,
  ZPX_CT_PALETTE,
  ZPX_CT_YCBCR,
  ZPX_CT_CMYK,
  ZPX_CT_YCCK
} zpx_colour_type;

typedef struct {
  zpx_format format;
  uint32_t width, height;
  uint8_t bits;          /* stored sample depth (1..16) */
  uint8_t channels;      /* what decoding yields at the stored depth */
  zpx_colour_type colour_type;
  int alpha, interlaced, animated;
  /* PNG pHYs (unit 1: per metre) or JPEG APP0 (1: per inch, 2: per cm). */
  int density_unit;      /* -1 absent, 0 aspect ratio only */
  uint32_t density_x, density_y;
  int orientation;       /* EXIF 0x0112: 1..8, 0 absent or unreadable */
  double gamma;          /* PNG gAMA, 0 absent */
  int srgb;              /* PNG sRGB rendering intent, -1 absent */
  int has_chrm;
  double chrm[8];        /* white x, y; red x, y; green x, y; blue x, y */
  int has_cicp;
  uint8_t cicp[4];       /* primaries, transfer, matrix, full range */
  int qoi_linear;        /* QOI colourspace byte: 1 linear, 0 sRGB */
  /* ICC: PNG iCCP zlib stream (icc_compressed), WebP ICCP payload, or the
   * first JPEG APP2 segment's payload with icc_segments > 0. */
  size_t icc_off, icc_len;
  int icc_compressed, icc_segments;
  size_t exif_off, exif_len; /* the TIFF header onward */
  /* Animated WebP's first frame, or an extended still WebP's VP8L chunk
   * (webp_rebuild): what zpx_int_webp_first_frame() rebuilds as a still. */
  size_t frame_off, frame_len;
  uint32_t frame_x, frame_y, frame_w, frame_h;
  int frame_alph;
  /* A still extended WebP (VP8X) whose bitstream is VP8L. Wuffs
   * v0.4.0-alpha.12 fails on every such file ("bad color cache", or "bad
   * ALPH+VP8L combination" with the alpha flag set) though the same VP8L
   * chunk decodes as a simple file, so the decoder rebuilds one from the
   * frame fields, which then name the VP8L chunk. */
  int webp_rebuild;
} zpx_meta;

/* What probing an image found, and why it failed when it did. `detail` is
 * a static string (an upstream status message or zupix's own) or NULL. */
typedef struct {
  zpx_format format;
  uint32_t width, height;
  uint8_t bits;      /* decoded sample depth: 8 or 16 */
  uint8_t channels;  /* 1 grey, 2 grey and alpha, 3 RGB, 4 RGBA */
  uint64_t workbuf_len;
  zpx_limit_kind limit;
  uint64_t limit_value, limit_cap;
  const char *detail;
  zpx_meta meta;
} zpx_int_probe;

zpx_status zpx_int_scan(const uint8_t *buf, size_t len,
                        const zpx_limits *limits, zpx_meta *m,
                        const char **detail);

/* The ICC profile's bytes. With dst NULL, sets *out_len to the size; with
 * dst, *out_len is its capacity on entry and the size on return. PNG's
 * profile is inflated, bounded by max_metadata. */
zpx_status zpx_int_icc(const uint8_t *buf, size_t len, const zpx_meta *m,
                       const zpx_limits *limits, uint8_t *dst, size_t *out_len,
                       const char **detail);

/* EXIF orientation from a TIFF block; 0 when absent or unreadable. */
int zpx_int_exif_orientation(const uint8_t *tiff, size_t len);

/* An animated WebP's first frame as a still WebP file (RIFF, an optional
 * VP8X with the alpha flag, the frame's ALPH, VP8 or VP8L chunks), written
 * to dst of at least m->frame_len + 30 bytes; returns its length. */
size_t zpx_int_webp_first_frame(const uint8_t *buf, const zpx_meta *m,
                                uint8_t *dst);

/* zpx_decode.c. Scans the header and checks max_side and max_pixels;
 * allocates nothing beyond the decoder's own state, freed before return. */
zpx_status zpx_int_probe_image(const uint8_t *buf, size_t len,
                               const zpx_limits *limits, zpx_int_probe *out);

/* Decodes the first frame into dst, which holds `height` rows of `stride`
 * bytes. pixfmt is ZPX_PIX_RGBA8 or ZPX_PIX_RGBA16. Probes again, so a
 * caller that skips zpx_int_probe_image() is still held to the limits. */
zpx_status zpx_int_decode_image(const uint8_t *buf, size_t len,
                                const zpx_limits *limits, zpx_pixfmt pixfmt,
                                uint8_t *dst, size_t stride, size_t dst_len,
                                zpx_int_probe *out);

/* ---- encoding ------------------------------------------------------- */

/* A growable in-memory sink (zpx_sink.c): `data` is malloc'd and owned by
 * the caller once encoding returns. */
typedef struct {
  uint8_t *data;
  size_t len, cap;
} zpx_buffer;

int zpx_int_buffer_write(void *closure, const uint8_t *data, size_t len);

/* Interleaved row-major samples, `channels` per pixel (1..4), each a byte
 * (bits 8) or a native-endian uint16_t (bits 16). */
zpx_status zpx_int_encode_png(const uint8_t *src, uint32_t width,
                              uint32_t height, int channels, int bits,
                              const zpx_png_opts *opts, zpx_write_fn write,
                              void *closure, const char **detail);

/* Grey (1 channel) or RGB (3) bytes. */
zpx_status zpx_int_encode_jpeg(const uint8_t *src, uint32_t width,
                               uint32_t height, int channels,
                               const zpx_jpeg_opts *opts, zpx_write_fn write,
                               void *closure, const char **detail);

/* RGB (3) or RGBA (4) bytes. */
zpx_status zpx_int_encode_webp(const uint8_t *src, uint32_t width,
                               uint32_t height, int channels,
                               const zpx_webp_opts *opts, zpx_write_fn write,
                               void *closure, const char **detail);

/* RGB or RGBA bytes; colourspace 0 sRGB, 1 linear. */
zpx_status zpx_int_encode_qoi(const uint8_t *src, uint32_t width,
                              uint32_t height, int channels, int colourspace,
                              zpx_write_fn write, void *closure,
                              const char **detail);

#endif
