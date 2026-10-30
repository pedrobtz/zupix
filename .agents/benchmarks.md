# zupix benchmarks

Written by `tools/run-benchmarks` on 2026-10-31: R 4.5.2, macOS Sequoia 15.7.9, x86_64.
Packages: zupix 0.0.0.9000, png 0.1.9, jpeg 0.1.11, webp 1.3.0.

The image is a seeded 4000 x 3000 synthetic photograph (12 megapixels,
RGB). Medians of at least five runs. `webp::read_webp()` returns doubles;
zupix's rows return a nativeRaster.

## Design §10 targets

| operation | target | measured |
| --- | --- | --- |
| PNG decode to nativeRaster | at most 1.0x png::readPNG() | 1.15x |
| JPEG decode to nativeRaster | within 2x of jpeg::readJPEG() | 0.36x |
| WebP decode | within 2x of webp::read_webp() | 0.1x |
| PNG encode, level 6 | within 1.5x of png::writePNG() | 1.26x |
| PNG encode size | no larger than png::writePNG() | 1x |
| JPEG encode, quality 90 | within 3x of jpeg::writeJPEG() | 1.51x |
| WebP encode | within 1.1x of webp::write_webp() | 0.83x |
| pix_info() on 1,000 files | under 1 s | 0.184 s |
qoi is not measured: qoi 0.1.0's writeQOI() overflows the C stack on an
image this size, and design §10 sets no QOI target.

## Decoding

| operation | median_s | mem_mb |
| --- | --- | --- |
| png::readPNG(native = TRUE) | 0.190 |  91.6 |
| pix_read(png) | 0.219 |  66.3 |
| jpeg::readJPEG(native = TRUE) | 0.179 |  80.1 |
| pix_read(jpeg) | 0.064 |  47.8 |
| webp::read_webp() | 2.519 | 778.4 |
| pix_read(webp) | 0.247 |  45.9 |

## Encoding

| operation | median_s | mem_mb |
| --- | --- | --- |
| png::writePNG() | 2.245 |  75.2 |
| pix_write_png(compression = 6) | 2.821 |  54.8 |
| jpeg::writeJPEG(quality = 0.9) | 0.569 |  36.3 |
| pix_write_jpeg(quality = 90) | 0.859 |  36.1 |
| webp::write_webp(quality = 75) | 1.842 | 343.5 |
| pix_write_webp(quality = 75) | 1.524 |  34.5 |

## Input file sizes

| format | bytes |
| --- | --- |
| png | 21340174 |
| jpeg |  2108845 |
| webp |   169978 |
