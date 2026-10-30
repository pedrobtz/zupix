# zupix benchmarks

Written by `tools/run-benchmarks` on 2026-10-30: R 4.5.2, macOS Sequoia 15.7.9, x86_64.
Packages: png 0.1.9, jpeg 0.1.11, webp 1.3.0.

The image is a seeded 4000 x 3000 synthetic photograph (12 megapixels,
RGB). Medians of at least five runs. zupix's own rows arrive with the
stages that build each codec; design §10 sets the targets against these.
qoi is not measured: qoi 0.1.0's writeQOI() overflows the C stack on an
image this size, and design §10 sets no QOI target.

## Baseline: decoding

| operation | median_s | mem_mb |
| --- | --- | --- |
| png::readPNG(native = TRUE) | 0.251 |  91.6 |
| jpeg::readJPEG(native = TRUE) | 0.180 |  80.1 |
| webp::read_webp() | 2.531 | 778.4 |

## Baseline: encoding

| operation | median_s | mem_mb |
| --- | --- | --- |
| png::writePNG() | 2.166 |  75.2 |
| jpeg::writeJPEG(quality = 0.9) | 0.574 |  36.3 |
| webp::write_webp(quality = 75) | 1.844 | 343.5 |

## Baseline: file sizes

| format | bytes |
| --- | --- |
| png | 21340174 |
| jpeg |  2108845 |
| webp |   169978 |
