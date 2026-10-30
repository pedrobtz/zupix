# Changelog

## zupix 0.0.0.9000

- Initial CRAN submission.

- [`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
  decodes PNG (every colour type and depth, palettes, `tRNS`, Adam7),
  JPEG (baseline and progressive; grey, YCbCr, CMYK and YCCK to RGB),
  WebP (lossy, lossy with alpha, lossless) and QOI into a
  `nativeRaster`, a double array in `[0, 1]` or an integer array with a
  `bits` attribute, from a path, raw vector or connection. `bits` and
  `channels` force the depth and add channels.
  [`pix_format()`](https://pedrobtz.github.io/zupix/reference/pix_format.md)
  names an image’s format from its signature. Animated PNG and WebP
  decode their first frame, flagged by an `animated` attribute.

- [`pix_info()`](https://pedrobtz.github.io/zupix/reference/pix_info.md)
  reports format, size, depth, colour type, alpha, interlacing,
  animation, density, EXIF orientation, the PNG colour chunks (`gAMA`,
  `cHRM`, `sRGB`, `cICP`) and whether ICC and EXIF data are present,
  without decoding pixels, for any number of files.
  [`pix_icc()`](https://pedrobtz.github.io/zupix/reference/pix_icc.md)
  and
  [`pix_exif()`](https://pedrobtz.github.io/zupix/reference/pix_icc.md)
  return the raw ICC profile and EXIF block.

- [`pix_write()`](https://pedrobtz.github.io/zupix/reference/pix_write.md),
  [`pix_write_png()`](https://pedrobtz.github.io/zupix/reference/pix_write.md)
  and
  [`pix_write_qoi()`](https://pedrobtz.github.io/zupix/reference/pix_write.md)
  encode the shapes
  [`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
  returns, to a file or a raw vector. PNG is zupix’s own writer over
  zlib, at 8 or 16 bits with 1 to 4 channels, an optional ICC profile,
  EXIF block or sRGB intent; QOI uses the reference encoder.

- [`pix_orient()`](https://pedrobtz.github.io/zupix/reference/pix_orient.md)
  applies an EXIF orientation losslessly; `pix_read(orient = TRUE)` does
  so while reading. Pixels come back as stored by default.

- [`pix_limits()`](https://pedrobtz.github.io/zupix/reference/pix_limits.md)
  bounds what an image may make zupix allocate: every size an image
  declares is checked before anything is allocated, and a breach is a
  `zupix_limit_error`. Every error is a classed condition inheriting
  from `zupix_error` (see `?zupix-conditions`).

- [`zupix_info()`](https://pedrobtz.github.io/zupix/reference/zupix_info.md)
  reports the bundled Wuffs, libjpeg-turbo, libwebp and `qoi.h`
  versions, their upstream commits and local patches, the linked zlib
  version, and whether Wuffs’s SIMD code was compiled.
