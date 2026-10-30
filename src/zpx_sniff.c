#include <string.h>

#include "zpx_core.h"

/* Signatures only; the extension is never consulted (design §6.1). */
zpx_format zpx_sniff(const uint8_t *buf, size_t len) {
  static const uint8_t png[8] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'};
  if (buf == NULL) return ZPX_FMT_UNKNOWN;
  if (len >= 8 && memcmp(buf, png, 8) == 0) return ZPX_FMT_PNG;
  if (len >= 3 && buf[0] == 0xff && buf[1] == 0xd8 && buf[2] == 0xff)
    return ZPX_FMT_JPEG;
  if (len >= 12 && memcmp(buf, "RIFF", 4) == 0 &&
      memcmp(buf + 8, "WEBP", 4) == 0)
    return ZPX_FMT_WEBP;
  if (len >= 4 && memcmp(buf, "qoif", 4) == 0) return ZPX_FMT_QOI;
  return ZPX_FMT_UNKNOWN;
}

const char *zpx_status_string(zpx_status s) {
  switch (s) {
  case ZPX_OK: return "ok";
  case ZPX_ERR_FORMAT: return "unknown or mismatched image format";
  case ZPX_ERR_DECODE: return "corrupt, truncated or inconsistent image";
  case ZPX_ERR_UNSUPPORTED: return "unsupported image feature";
  case ZPX_ERR_LIMIT: return "image exceeds a limit";
  case ZPX_ERR_MEMORY: return "memory allocation failed";
  case ZPX_ERR_ARGUMENT: return "invalid argument";
  case ZPX_ERR_ENCODE: return "encoding failed";
  case ZPX_ERR_SINK: return "the output sink failed";
  }
  return "unknown status";
}
