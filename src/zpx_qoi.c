/* The one translation unit that compiles qoi.h's implementation. zupix
 * uses only qoi_encode(); QOI decoding goes through Wuffs (design D1), so
 * qoi_decode() is compiled but never called. */

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
  if (out == NULL) return ZPX_ERR_MEMORY;
  failed = write(closure, (const uint8_t *) out, (size_t) len);
  QOI_FREE(out);
  return failed ? ZPX_ERR_SINK : ZPX_OK;
}
