# Conditions raised by zupix

Every error zupix raises is a condition of class `zupix_error` with one
more specific subclass. Handle them by class, for example with
`tryCatch(..., zupix_limit_error = function(e) ...)`, never by matching
the message text, which may change.

## Details

- `zupix_input_error`: an argument is invalid, or `channels` asks to
  remove a channel the image has. Field `arg` names the argument.

- `zupix_format_error`: the input has no PNG, JPEG, WebP or QOI
  signature, or `format` names a different format from the one the
  signature shows.

- `zupix_unsupported_error`: the image is valid but uses a feature zupix
  does not decode.

- `zupix_decode_error`: the image is corrupt, truncated or inconsistent.
  No partial image is returned.

- `zupix_limit_error`: a limit from
  [`pix_limits()`](https://pedrobtz.github.io/zupix/reference/pix_limits.md)
  was exceeded. Fields `limit` (its name, such as `"max_pixels"`),
  `value` (what the image needs) and `cap` (the limit). Raised before
  the pixels are allocated.

- `zupix_encode_error`: an encoder failed or a format's own limit was
  hit.

- `zupix_io_error`: a file or connection could not be read or written.

- `zupix_memory_error`: memory could not be allocated.

- `zupix_internal_error`: zupix's C code returned a status it should
  never return. This is a bug; please report it.

Each condition from a decoder also carries `format`, the format being
decoded, and `detail`, the decoder's own message where there is one.
