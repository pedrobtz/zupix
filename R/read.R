#' Read an image
#'
#' Decodes a PNG, JPEG, WebP or QOI image into one of three shapes. The
#' pixels are the ones the file holds: no colour conversion, gamma or ICC
#' profile is applied, and EXIF orientation is applied only when asked.
#' Animated PNG and WebP decode their first frame, with attribute
#' `animated` set to `TRUE`. CMYK and YCCK JPEG decode to RGB without
#' colour management.
#'
#' @param x A file path, a raw vector holding the file's bytes, or a
#'   connection, which is read whole (up to `max_bytes` of `limits`).
#' @param as The shape of the result:
#'   * `"native"`: a `nativeRaster`, 8-bit RGBA, as
#'     `png::readPNG(native = TRUE)` returns. 16-bit samples are rounded to
#'     8 bits.
#'   * `"double"`: a `height x width x channels` array of values in
#'     `[0, 1]`, or a matrix for one channel, as `png::readPNG()` returns.
#'     16-bit precision is kept.
#'   * `"integer"`: the same shape holding the sample values, `0..255` or
#'     `0..65535`, with attribute `bits` (`8L` or `16L`).
#' @param bits `NULL` keeps the file's depth (1-, 2- and 4-bit PNGs become
#'   8); `8L` or `16L` forces it. Not used by `as = "native"`.
#' @param channels `NULL` keeps the file's channels: 1 grey, 2 grey and
#'   alpha, 3 RGB, 4 RGBA; a palette becomes 3, or 4 when it has
#'   transparency. A larger number adds channels (grey to RGB, an opaque
#'   alpha); a smaller one is an error, because removing colour or alpha is
#'   a colour decision. Not used by `as = "native"`.
#' @param orient `TRUE` applies the image's EXIF orientation (see
#'   [pix_orient()]); `FALSE`, the default, returns the pixels as stored.
#' @param format `"auto"` reads the format from the file's signature, never
#'   its extension. A named format (`"png"`, `"jpeg"`, `"webp"`, `"qoi"`)
#'   that disagrees with the signature is an error.
#' @param limits Limits checked before anything is allocated; see
#'   [pix_limits()].
#' @return The image, in the shape `as` asks for.
#' @seealso [zupix-conditions] for the errors raised.
#' @export
#' @examples
#' f <- system.file("extdata", "gradient.png", package = "zupix")
#' img <- pix_read(f)
#' dim(img)
#' str(pix_read(f, as = "integer"))
#' range(pix_read(f, as = "double"))
pix_read <- function(
  x,
  as = c("native", "double", "integer"),
  bits = NULL,
  channels = NULL,
  orient = FALSE,
  format = "auto",
  limits = pix_limits()
) {
  as <- match_arg(as, c("native", "double", "integer"), "as")
  bits <- check_choice_int(bits, c(8L, 16L), "bits")
  channels <- check_choice_int(channels, 1:4, "channels")
  if (!isTRUE(orient) && !isFALSE(orient)) {
    zpx_input_error("orient", "`orient` must be TRUE or FALSE.")
  }
  format <- match_arg(format, c("auto", zpx_formats), "format")
  lim <- check_limits(limits)

  bytes <- read_input(x, lim[[3L]])
  res <- .Call(
    zpx_r_read,
    bytes,
    match(as, c("native", "double", "integer")),
    bits,
    channels,
    match(format, c("auto", zpx_formats)) - 1L,
    lim
  )
  if (inherits(res, "zupix_failure")) {
    zpx_raise_failure(res, sniffed_format(bytes))
  }

  out <- res$pixels
  if (as == "native") {
    dim(out) <- c(res$height, res$width)
    attr(out, "channels") <- 4L
    class(out) <- "nativeRaster"
  } else {
    dim(out) <- if (res$channels == 1L) {
      c(res$height, res$width)
    } else {
      c(res$height, res$width, res$channels)
    }
    if (as == "integer") {
      attr(out, "bits") <- res$bits
    }
  }
  if (orient && res$orientation > 1L) {
    out <- pix_orient(out, res$orientation)
  }
  if (res$animated) {
    attr(out, "animated") <- TRUE
  }
  out
}

#' Identify an image's format
#'
#' Reads the signature at the start of a file or raw vector. The file's
#' extension is never consulted.
#'
#' @inheritParams pix_read
#' @return `"png"`, `"jpeg"`, `"webp"`, `"qoi"`, or `NA` when the signature
#'   is none of these.
#' @export
#' @examples
#' pix_format(as.raw(c(0x71, 0x6f, 0x69, 0x66)))
#' pix_format(charToRaw("not an image"))
pix_format <- function(x) {
  bytes <- if (is.raw(x)) x else read_input(x, Inf, n = 16L)
  sniffed_format(bytes)
}

sniffed_format <- function(bytes) {
  code <- .Call(zpx_r_sniff, bytes)
  if (code == 0L) NA_character_ else zpx_formats[[code]]
}

# The bytes of `x`: a raw vector as is; a path or connection read whole, or
# its first `n` bytes. More than `max_bytes` is a zupix_limit_error, raised
# before reading a file that is already too big and as soon as a connection
# passes the cap.
read_input <- function(x, max_bytes, n = Inf, call = sys.call(-1L)) {
  if (is.raw(x)) {
    return(x)
  }
  if (
    !inherits(x, "connection") &&
      (!is.character(x) || length(x) != 1L || is.na(x))
  ) {
    zpx_input_error(
      "x",
      "`x` must be a file path, a raw vector or a connection.",
      call = call
    )
  }
  # zu_open_input() raises a missing file or directory through `abort` and
  # a source that cannot be opened through `fail`: both are I/O errors here,
  # while a connection in the wrong state is an invalid argument.
  abort <- function(arg, message) {
    kind <- if (grepl("^(no such file|not a file)", message)) "io" else "input"
    zpx_abort(kind, paste0(message, "."), arg = arg, call = call)
  }
  fail <- function(message) zpx_abort("io", message, call = call)
  if (is.character(x) && !is.finite(n) && file.exists(x) && !dir.exists(x)) {
    size <- file.size(x)
    if (!is.na(size) && size > max_bytes) {
      zpx_limit_error(
        "max_bytes",
        size,
        max_bytes,
        sprintf(
          "The file has %s bytes, more than `max_bytes` (%s).",
          fmt_num(size),
          fmt_num(max_bytes)
        ),
        call = call
      )
    }
  }
  src <- zu_open_input(
    x,
    what = "x",
    prefix = "zupix",
    abort = abort,
    fail = fail
  )
  if (src$close) {
    on.exit(close(src$con), add = TRUE)
  }
  if (is.finite(n)) {
    return(readBin(src$con, "raw", n = n))
  }
  chunks <- list()
  total <- 0
  repeat {
    b <- readBin(src$con, "raw", n = 1048576L)
    if (length(b) == 0L) {
      break
    }
    total <- total + length(b)
    if (total > max_bytes) {
      zpx_limit_error(
        "max_bytes",
        total,
        max_bytes,
        sprintf(
          "The input is longer than `max_bytes` (%s bytes).",
          fmt_num(max_bytes)
        ),
        call = call
      )
    }
    chunks[[length(chunks) + 1L]] <- b
  }
  if (length(chunks) == 0L) raw() else unlist(chunks, use.names = FALSE)
}

match_arg <- function(x, choices, arg, call = sys.call(-1L)) {
  if (identical(x, choices)) {
    return(choices[[1L]])
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !x %in% choices) {
    zpx_input_error(
      arg,
      sprintf(
        "`%s` must be one of %s.",
        arg,
        paste0("\"", choices, "\"", collapse = ", ")
      ),
      call = call
    )
  }
  x
}

check_choice_int <- function(x, choices, arg, call = sys.call(-1L)) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !x %in% choices) {
    zpx_input_error(
      arg,
      sprintf(
        "`%s` must be NULL or one of %s.",
        arg,
        paste(choices, collapse = ", ")
      ),
      call = call
    )
  }
  as.integer(x)
}
