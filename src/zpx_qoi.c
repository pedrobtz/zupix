/* The one translation unit that compiles qoi.h's implementation: qoi_encode()
 * for writing, and since Stage 10 qoi_decode() for reading. Wuffs
 * v0.4.0-alpha.12 decodes QOI wrongly (a QOI_OP_RUN's pixel never enters the
 * colour index), so QOI decodes through the format's reference decoder
 * (design D1, amended 2026-10-31). */

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#define QOI_IMPLEMENTATION
#define QOI_NO_STDIO
#include "vendor/qoi/qoi.h"

#include "zpx_core.h"

zpx_status zpx_int_encode_qoi(const uint8_t *src, uint32_t width,
                              uint32_t height, int channels, int colourspace,
                              zpx_write_fn write, void *closure,
                              const char **detail) {
  qoi_desc desc;
  int len = 0, failed;
  void *out;
  if ((channels != 3 && channels != 4) || width == 0 || height == 0) {
    *detail = "QOI needs 3 or 4 channels and a non-empty image";
    return ZPX_ERR_ARGUMENT;
  }
  if (height >= QOI_PIXELS_MAX / width) {
    *detail = "QOI holds at most 400,000,000 pixels";
    return ZPX_ERR_ENCODE;
  }
  desc.width = width;
  desc.height = height;
  desc.channels = (unsigned char) channels;
  desc.colorspace = (unsigned char) (colourspace ? QOI_LINEAR : QOI_SRGB);
  out = qoi_encode(src, &desc, &len);
  /* Untested: qoi_encode() fails only on allocation, `desc` having been
   * checked above, and R's sink only when out of memory (zpx_sink.c). */
  if (out == NULL) return ZPX_ERR_MEMORY;
  failed = write(closure, (const uint8_t *) out, (size_t) len);
  QOI_FREE(out);
  return failed ? ZPX_ERR_SINK : ZPX_OK;
}

/* Whether the chunk stream after the 14-byte header yields `pixels` pixels
 * before the 8-byte end marker, and the marker is there. qoi_decode() is
 * memory-safe on any input of at least the header and marker, but it
 * repeats the last pixel when the stream runs short; zupix returns a
 * truncated file as an error, never a partial image (design §6.5). One
 * bounded pass: every step consumes at least one byte. */
static int stream_complete(const uint8_t *b, size_t len, uint64_t pixels) {
  size_t end = len - sizeof qoi_padding, p = QOI_HEADER_SIZE;
  uint64_t px = 0;
  if (memcmp(b + end, qoi_padding, sizeof qoi_padding) != 0) return 0;
  while (px < pixels) {
    uint8_t op;
    size_t extra;
    if (p >= end) return 0;
    op = b[p++];
    extra = op == QOI_OP_RGB    ? 3
          : op == QOI_OP_RGBA   ? 4
          : (op & QOI_MASK_2) == QOI_OP_LUMA ? 1
                                : 0;
    if (extra > end - p) return 0;
    p += extra;
    px += ((op & QOI_MASK_2) == QOI_OP_RUN && op != QOI_OP_RGB &&
           op != QOI_OP_RGBA)
              ? (uint64_t) (op & 0x3f) + 1
              : 1;
  }
  return 1;
}

/* Decodes a QOI file the scanner has already read the header of, into
 * `height` rows of RGBA8 at `stride`. The caller has checked the limits,
 * qoi_decode()'s own width * height * 4 output included. */
zpx_status zpx_int_qoi_decode(const uint8_t *buf, size_t len, uint32_t width,
                              uint32_t height, uint8_t *dst, size_t stride,
                              const char **detail) {
  uint8_t *rgba;
  qoi_desc desc;
  if (len < QOI_HEADER_SIZE + sizeof qoi_padding) {
    *detail = "QOI is truncated";
    return ZPX_ERR_DECODE;
  }
  if (len > INT_MAX) {
    /* Untested: needs a 2 GiB input, too large for the test suite. */
    *detail = "QOI input over 2 GiB";
    return ZPX_ERR_UNSUPPORTED;
  }
  if (!stream_complete(buf, len, (uint64_t) width * height)) {
    *detail = "QOI stream is truncated or lacks its end marker";
    return ZPX_ERR_DECODE;
  }
  rgba = (uint8_t *) qoi_decode(buf, (int) len, &desc, 4);
  if (rgba == NULL) {
    *detail = "QOI header is invalid";
    return ZPX_ERR_DECODE;
  }
  if (desc.width != width || desc.height != height) {
    /* Untested: qoi_decode() reads the same header bytes the scanner did,
     * so the sizes cannot differ; kept so that a change to either side
     * fails safe. */
    QOI_FREE(rgba);
    *detail = "the container and the decoder disagree on the image size";
    return ZPX_ERR_DECODE;
  }
  for (uint32_t y = 0; y < height; y++)
    memcpy(dst + (size_t) y * stride, rgba + (size_t) y * width * 4,
           (size_t) width * 4);
  QOI_FREE(rgba);
  return ZPX_OK;
}
