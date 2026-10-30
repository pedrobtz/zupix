# Changelog

## zupix 0.0.0.9000

- Initial CRAN submission.

- [`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
  decodes PNG (every colour type and depth, palettes, `tRNS`, Adam7) and
  QOI into a `nativeRaster`, a double array in `[0, 1]` or an integer
  array with a `bits` attribute, from a path, raw vector or connection.
  `bits` and `channels` force the depth and add channels.
  [`pix_format()`](https://pedrobtz.github.io/zupix/reference/pix_format.md)
  names an image’s format from its signature.

- [`pix_limits()`](https://pedrobtz.github.io/zupix/reference/pix_limits.md)
  bounds what an image may make zupix allocate: every size an image
  declares is checked before anything is allocated, and a breach is a
  `zupix_limit_error`. Every error is a classed condition inheriting
  from `zupix_error` (see `?zupix-conditions`).

- [`zupix_info()`](https://pedrobtz.github.io/zupix/reference/zupix_info.md)
  reports the bundled Wuffs, libjpeg-turbo, libwebp and `qoi.h`
  versions, their upstream commits and local patches, the linked zlib
  version, and whether Wuffs’s SIMD code was compiled.
