# zupix 0.0.0.9000

* Initial CRAN submission.

* `pix_read()` decodes PNG (every colour type and depth, palettes, `tRNS`,
  Adam7), JPEG (baseline and progressive; grey, YCbCr, CMYK and YCCK to RGB),
  WebP (lossy, lossy with alpha, lossless) and QOI into a `nativeRaster`, a
  double array in `[0, 1]` or an integer array with a `bits` attribute, from
  a path, raw vector or connection. `bits` and `channels` force the depth
  and add channels. `pix_format()` names an image's format from its
  signature. Animated PNG and WebP decode their first frame, flagged by an
  `animated` attribute.

* `pix_info()` reports format, size, depth, colour type, alpha,
  interlacing, animation, density, EXIF orientation, the PNG colour chunks
  (`gAMA`, `cHRM`, `sRGB`, `cICP`) and whether ICC and EXIF data are
  present, without decoding pixels, for any number of files. `pix_icc()` and
  `pix_exif()` return the raw ICC profile and EXIF block.

* `pix_write()`, `pix_write_png()`, `pix_write_jpeg()`, `pix_write_webp()`
  and `pix_write_qoi()` encode the shapes `pix_read()` returns, to a file or
  a raw vector. PNG is zupix's own writer over zlib, at 8 or 16 bits with 1
  to 4 channels; JPEG uses libjpeg-turbo (quality, subsampling,
  progressive); WebP uses libwebp (lossy or lossless); QOI uses the
  reference encoder. PNG, JPEG and WebP embed an optional ICC profile and
  EXIF block.

* `pix_orient()` applies an EXIF orientation losslessly; `pix_read(orient =
  TRUE)` does so while reading. Pixels come back as stored by default.

* `pix_limits()` bounds what an image may make zupix allocate: every size an
  image declares is checked before anything is allocated, and a breach is a
  `zupix_limit_error`. Every error is a classed condition inheriting from
  `zupix_error` (see `?zupix-conditions`).

* `zupix_info()` reports the bundled Wuffs, libjpeg-turbo, libwebp and
  `qoi.h` versions, their upstream commits and local patches, the linked
  zlib version, and whether Wuffs's SIMD code was compiled.
