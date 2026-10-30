# Identify an image's format

Reads the signature at the start of a file or raw vector. The file's
extension is never consulted.

## Usage

``` r
pix_format(x)
```

## Arguments

- x:

  A file path, a raw vector holding the file's bytes, or a connection,
  which is read whole (up to `max_bytes` of `limits`).

## Value

`"png"`, `"jpeg"`, `"webp"`, `"qoi"`, or `NA` when the signature is none
of these.

## Examples

``` r
pix_format(as.raw(c(0x71, 0x6f, 0x69, 0x66)))
#> [1] "qoi"
pix_format(charToRaw("not an image"))
#> [1] NA
```
