# Thin wrappers over the C consumer; every call goes through zupix's table.
# Pixel formats and statuses are zupix.h's enum values.

zt_table <- function() .Call(C_zt_table)
zt_future_abi <- function() .Call(C_zt_future_abi)
zt_probe <- function(x) {
  v <- .Call(C_zt_probe, x)
  names(v) <- c(
    "status",
    "format",
    "width",
    "height",
    "bits",
    "channels",
    "orientation",
    "animated"
  )
  v
}
zt_decode <- function(x, pixfmt) {
  .Call(C_zt_decode, x, as.integer(pixfmt))
}
zt_metadata <- function(x, which = c("icc", "exif")) {
  which <- match.arg(which)
  .Call(C_zt_metadata, x, if (which == "icc") 1L else 2L)
}
zt_encode <- function(pixels, format, pixfmt, width, height) {
  .Call(
    C_zt_encode,
    pixels,
    as.integer(format),
    as.integer(pixfmt),
    as.integer(width),
    as.integer(height),
    FALSE
  )
}
zt_encode_failing_sink <- function(pixels, format, pixfmt, width, height) {
  .Call(
    C_zt_encode,
    pixels,
    as.integer(format),
    as.integer(pixfmt),
    as.integer(width),
    as.integer(height),
    TRUE
  )
}
zt_status_string <- function(status) {
  .Call(C_zt_status_string, as.integer(status))
}
