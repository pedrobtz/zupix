/* zupix.h: zupix's image codecs for other packages' C code (design §7).
 *
 * Pure C99: no R header, no vendored header. A consumer declares
 * `Imports: zupix` and `LinkingTo: zupix`, adds `importFrom(zupix,
 * pix_read)` (or any export) to its NAMESPACE so zupix's DLL is loaded
 * first, includes "zupix-r.h", and calls through the table zupix_api()
 * returns:
 *
 *   const zupix_api_v1 *api = zupix_api();
 *   if (api == NULL) ... zupix speaks another ABI version ...
 *   zpx_info info = {sizeof info};
 *   if (api->probe(buf, len, NULL, &info) == ZPX_OK) ...
 *
 * Nothing in the table raises an R error or calls R, so it may be called
 * from inside another library's callbacks. zupix_api() itself raises an R
 * error if zupix's DLL is not loaded, so make its first call from R-safe
 * code (see zupix-r.h). Every struct a caller passes
 * starts with struct_size, set to sizeof the struct. Pixels are
 * interleaved, row-major, top row first; 16-bit samples are native-endian
 * uint16_t. Decoding never applies colour management, gamma or EXIF
 * orientation: the pixels are the ones the file holds.
 */

#ifndef ZUPIX_H
#define ZUPIX_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ZUPIX_ABI_VERSION 1u

typedef enum {
  ZPX_OK = 0,
  ZPX_ERR_FORMAT,      /* unknown signature */
  ZPX_ERR_DECODE,      /* corrupt, truncated or inconsistent input */
  ZPX_ERR_UNSUPPORTED, /* a valid feature zupix does not handle */
  ZPX_ERR_LIMIT,       /* a zpx_limits limit, before allocation */
  ZPX_ERR_MEMORY,
  ZPX_ERR_ARGUMENT,    /* a bad argument, or a channel reduction */
  ZPX_ERR_ENCODE,      /* an encoder failed or a format limit was hit */
  ZPX_ERR_SINK         /* the zpx_write_fn returned non-zero */
} zpx_status;

typedef enum {
  ZPX_FMT_UNKNOWN = 0,
  ZPX_FMT_PNG,
  ZPX_FMT_JPEG,
  ZPX_FMT_WEBP,
  ZPX_FMT_QOI
} zpx_format;

/* Pixel layouts for decoding into and encoding from. Decoding adds
 * channels (grey to RGB, an opaque alpha) but never removes them: Y8 or
 * Y16 from a colour image, or RGB8 from one with alpha, is
 * ZPX_ERR_ARGUMENT, since dropping colour or alpha is a colour decision. */
typedef enum {
  ZPX_PIX_RGBA8 = 1,
  ZPX_PIX_RGB8,
  ZPX_PIX_Y8,
  ZPX_PIX_RGBA16,
  ZPX_PIX_Y16
} zpx_pixfmt;

/* Checked against an image's declared size before anything is allocated.
 * NULL where a function takes limits means zupix's defaults: 65,535 a
 * side, 10^8 pixels, 2 GiB, 16 MiB of metadata. */
typedef struct {
  uint32_t struct_size, max_side;
  uint64_t max_pixels, max_bytes, max_metadata;
} zpx_limits;

typedef struct {
  uint32_t struct_size;
  zpx_format format;
  uint32_t width, height;
  uint8_t bits;        /* decoded depth: 8, or 16 for 16-bit PNG */
  uint8_t channels;    /* 1 grey, 2 grey and alpha, 3 RGB, 4 RGBA */
  uint8_t orientation; /* EXIF orientation 1..8, 0 when absent */
  uint8_t animated;    /* APNG or animated WebP; the first frame decodes */
  size_t icc_len, exif_len; /* as stored (PNG iCCP compressed) */
} zpx_info;

/* Receives encoded output in order; return non-zero to abort, which the
 * encoder reports as ZPX_ERR_SINK. */
typedef int (*zpx_write_fn)(void *closure, const uint8_t *data, size_t len);

/* What metadata() extracts. */
#define ZPX_META_ICC 0x49434350u  /* 'ICCP': the ICC profile, inflated */
#define ZPX_META_EXIF 0x45584946u /* 'EXIF': TIFF header onward */

/* Per-format encoder options; NULL means the defaults shown. */
typedef struct {
  uint32_t struct_size;
  int compression; /* zlib level 0..9; default 6 */
  const uint8_t *icc;
  size_t icc_len;
  const uint8_t *exif;
  size_t exif_len;
  int srgb;        /* sRGB rendering intent 0..3, or -1 for none (default) */
} zpx_png_opts;

typedef struct {
  uint32_t struct_size;
  int quality;     /* 1..100, libjpeg's scale; default 90 */
  int subsampling; /* 0 4:4:4, 1 4:2:2, 2 4:2:0 (default) */
  int progressive; /* default 0 */
  const uint8_t *icc;
  size_t icc_len;
  const uint8_t *exif;
  size_t exif_len;
} zpx_jpeg_opts;

typedef struct {
  uint32_t struct_size;
  float quality;   /* 0..100; default 75 */
  int lossless;    /* default 0 */
  int method;      /* 0..6; default 4 */
  const uint8_t *icc;
  size_t icc_len;
  const uint8_t *exif;
  size_t exif_len;
} zpx_webp_opts;

typedef struct {
  uint32_t struct_size;
  int colourspace; /* 0 sRGB (default), 1 linear: a label only */
} zpx_qoi_opts;

typedef struct {
  uint32_t abi_version, struct_size;

  zpx_format (*sniff)(const uint8_t *buf, size_t len);

  /* Header and metadata, no pixel decode. info->struct_size must be set. */
  zpx_status (*probe)(const uint8_t *buf, size_t len,
                      const zpx_limits *limits, zpx_info *info);

  /* The first frame into dst: `height` rows of `stride` bytes. Probes and
   * checks the limits again, so it is safe without a prior probe(). */
  zpx_status (*decode)(const uint8_t *buf, size_t len,
                       const zpx_limits *limits, zpx_pixfmt pixfmt,
                       uint8_t *dst, size_t stride, size_t dst_len);

  /* ZPX_META_ICC or ZPX_META_EXIF. With dst NULL, sets *len to the size
   * (0 when absent); else *len is dst's capacity on entry and the size on
   * return. */
  zpx_status (*metadata)(const uint8_t *buf, size_t len, uint32_t fourcc,
                         uint8_t *dst, size_t *out_len);

  /* src holds `height` rows of `stride` bytes in `pixfmt`. opts is the
   * format's zpx_*_opts, or NULL. PNG takes every pixfmt; JPEG takes Y8,
   * RGB8 and an all-opaque RGBA8; WebP and QOI take RGB8 and RGBA8, and Y8
   * widened to RGB. 16-bit input is rounded to 8 bits for JPEG and WebP. */
  zpx_status (*encode)(zpx_format format, zpx_pixfmt pixfmt,
                       const uint8_t *src, uint32_t width, uint32_t height,
                       size_t stride, const void *opts, zpx_write_fn write,
                       void *closure);

  const char *(*status_string)(zpx_status status);
} zupix_api_v1;

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* ZUPIX_H */
