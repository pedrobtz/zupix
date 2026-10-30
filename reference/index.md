# Package index

## Reading

Decode an image into a nativeRaster or an array, under limits.

- [`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
  : Read an image
- [`pix_format()`](https://pedrobtz.github.io/zupix/reference/pix_format.md)
  : Identify an image's format
- [`pix_limits()`](https://pedrobtz.github.io/zupix/reference/pix_limits.md)
  : Limits on what an image may make zupix allocate

## Metadata

Header, ICC profile, EXIF data and orientation, without decoding.

- [`pix_info()`](https://pedrobtz.github.io/zupix/reference/pix_info.md)
  : Read an image's header and metadata
- [`pix_icc()`](https://pedrobtz.github.io/zupix/reference/pix_icc.md)
  [`pix_exif()`](https://pedrobtz.github.io/zupix/reference/pix_icc.md)
  : Extract an image's ICC profile or EXIF data
- [`pix_orient()`](https://pedrobtz.github.io/zupix/reference/pix_orient.md)
  : Apply an EXIF orientation

## Writing

- [`pix_write()`](https://pedrobtz.github.io/zupix/reference/pix_write.md)
  [`pix_write_png()`](https://pedrobtz.github.io/zupix/reference/pix_write.md)
  [`pix_write_qoi()`](https://pedrobtz.github.io/zupix/reference/pix_write.md)
  [`pix_write_jpeg()`](https://pedrobtz.github.io/zupix/reference/pix_write.md)
  [`pix_write_webp()`](https://pedrobtz.github.io/zupix/reference/pix_write.md)
  : Write an image

## Errors and build information

- [`zupix-conditions`](https://pedrobtz.github.io/zupix/reference/zupix-conditions.md)
  : Conditions raised by zupix
- [`zupix_info()`](https://pedrobtz.github.io/zupix/reference/zupix_info.md)
  : Build information
- [`zupix`](https://pedrobtz.github.io/zupix/reference/zupix-package.md)
  [`zupix-package`](https://pedrobtz.github.io/zupix/reference/zupix-package.md)
  : zupix: Read and Write 'PNG', 'JPEG', 'WebP' and 'QOI' Images
