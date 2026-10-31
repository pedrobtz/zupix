#' Limits on what an image may make zupix allocate
#'
#' Images are hostile input: a small file can declare a huge image. zupix
#' reads an image's header, checks it against these limits, and only then
#' allocates anything, so a breach raises a `zupix_limit_error` (see
#' [zupix-conditions]) before any pixel memory exists.
#'
#' The defaults can be changed for a session with the options
#' `zupix.max_side`, `zupix.max_pixels`, `zupix.max_bytes` and
#' `zupix.max_metadata`.
#'
#' @param max_side The largest width or height, in pixels. The default,
#'   65,535, is JPEG's own maximum.
#' @param max_pixels The largest `width * height`. The default is 10^8.
#' @param max_bytes The most memory one decode may use: the R result, its
#'   working copy and the decoder's work buffer together. The default is 2
#'   GiB. A 10^8-pixel RGBA image needs 3.2 GB as a double array but 400 MB
#'   as a `nativeRaster`. Inputs read from a file or connection are also
#'   capped at this size.
#' @param max_metadata The most bytes of metadata (ICC profile, EXIF) one
#'   image may carry. The default is 16 MiB.
#' @return A `zupix_limits` object, to pass as the `limits` argument of the
#'   readers.
#' @export
#' @examples
#' pix_limits()
#' pix_limits(max_pixels = 1e6)
pix_limits <- function(
  max_side = getOption("zupix.max_side", 65535L),
  max_pixels = getOption("zupix.max_pixels", 1e8),
  max_bytes = getOption("zupix.max_bytes", 2^31),
  max_metadata = getOption("zupix.max_metadata", 16 * 2^20)
) {
  structure(
    list(
      max_side = check_limit(max_side, "max_side", 2^32 - 1),
      max_pixels = check_limit(max_pixels, "max_pixels", 2^53),
      max_bytes = check_limit(max_bytes, "max_bytes", 2^53),
      max_metadata = check_limit(max_metadata, "max_metadata", 2^53)
    ),
    class = "zupix_limits"
  )
}

#' @export
print.zupix_limits <- function(x, ...) {
  cat("<zupix_limits>\n")
  for (nm in names(x)) {
    cat(sprintf("  %-13s %s\n", nm, fmt_num(x[[nm]])))
  }
  invisible(x)
}

check_limit <- function(x, arg, upper) {
  if (
    !is.numeric(x) ||
      length(x) != 1L ||
      is.na(x) ||
      x < 1 ||
      x > upper ||
      x != trunc(x)
  ) {
    zpx_input_error(
      arg,
      sprintf("`%s` must be a whole number from 1 to %s.", arg, fmt_num(upper)),
      call = sys.call(-1L)
    )
  }
  as.double(x)
}

check_limits <- function(limits, call = sys.call(-1L)) {
  if (!inherits(limits, "zupix_limits")) {
    zpx_input_error(
      "limits",
      "`limits` must come from `pix_limits()`.",
      call = call
    )
  }
  c(
    max_side = limits$max_side,
    max_pixels = limits$max_pixels,
    max_bytes = limits$max_bytes,
    max_metadata = limits$max_metadata
  )
}
