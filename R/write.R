#' Write an image
#'
#' `pix_write()` picks the format from `file`'s extension (or `format`) and
#' passes `...` to that format's writer. Without a `file`, `format` is
#' needed, and the encoded bytes are returned. The writers take the shapes
#' [pix_read()] returns:
#'
#' * a `nativeRaster` (8-bit RGBA);
#' * a double array or matrix with values in `[0, 1]`, clamped to that range
#'   and rounded to `bits`;
#' * an integer array or matrix of sample values. Its `bits` attribute gives
#'   the depth; without one it is 8-bit if every value is at most 255.
#'
#' A matrix is a grey image; a `height x width x channels` array has 1 to 4
#' channels (grey, grey and alpha, RGB, RGBA). `NA` is an error.
#'
#' @param x The image.
#' @param file A path to write, or `NULL` to return the encoded bytes.
#' @param format `NULL` to use `file`'s extension (`.png`, `.jpg`, `.jpeg`,
#'   `.webp`, `.qoi`), or `"png"`, `"jpeg"`, `"webp"` or `"qoi"`. Needed
#'   when `file` is `NULL`.
#' @param ... Arguments for the format's writer.
#' @return With `file`, `file`, invisibly; with `file = NULL`, a raw vector.
#' @seealso [pix_read()], and [zupix-conditions] for the errors raised.
#' @export
#' @examples
#' f <- system.file("extdata", "gradient.png", package = "zupix")
#' img <- pix_read(f, as = "integer")
#' out <- tempfile(fileext = ".qoi")
#' pix_write(img, out)
#' identical(pix_read(out, as = "integer"), img)
pix_write <- function(x, file = NULL, format = NULL, ...) {
  if (is.null(format)) {
    if (is.null(file)) {
      zpx_input_error("format", "`format` is needed when `file` is NULL.")
    }
    if (!is.character(file) || length(file) != 1L || is.na(file)) {
      zpx_input_error("file", "`file` must be a single path or NULL.")
    }
    ext <- tolower(tools::file_ext(file))
    format <- switch(
      ext,
      png = "png",
      qoi = "qoi",
      jpg = ,
      jpeg = "jpeg",
      webp = "webp",
      zpx_input_error(
        "format",
        sprintf(
          "Can't tell the format from extension \"%s\"; set `format`.",
          ext
        )
      )
    )
  }
  format <- match_arg(format, zpx_formats, "format")
  switch(
    format,
    png = pix_write_png(x, file, ...),
    jpeg = pix_write_jpeg(x, file, ...),
    webp = pix_write_webp(x, file, ...),
    qoi = pix_write_qoi(x, file, ...)
  )
}

#' @describeIn pix_write PNG at 8 or 16 bits, 1 to 4 channels, with an
#'   optional ICC profile, EXIF block or sRGB rendering intent.
#' @param bits `NULL` keeps the image's depth (8 for doubles and
#'   `nativeRaster`s); `8L` or `16L` forces it.
#' @param compression The zlib level, 0 (store) to 9 (smallest).
#' @param icc An ICC profile as a raw vector, written as `iCCP`.
#' @param exif An EXIF block (TIFF header onward) as a raw vector, written as
#'   `eXIf`.
#' @param srgb `NULL`, or the `sRGB` chunk's rendering intent: 0 perceptual,
#'   1 relative colorimetric, 2 saturation, 3 absolute colorimetric. PNG
#'   does not allow both `icc` and `srgb`.
#' @export
pix_write_png <- function(
  x,
  file = NULL,
  bits = NULL,
  compression = 6L,
  icc = NULL,
  exif = NULL,
  srgb = NULL
) {
  bits <- check_choice_int(bits, c(8L, 16L), "bits")
  compression <- check_choice_int(compression, 0:9, "compression", FALSE)
  check_raw_or_null(icc, "icc")
  check_raw_or_null(exif, "exif")
  srgb <- check_choice_int(srgb, 0:3, "srgb")
  if (!is.null(icc) && !is.null(srgb)) {
    zpx_input_error("srgb", "PNG allows `icc` or `srgb`, not both.")
  }
  px <- prepare_pixels(x, bits)
  opts <- encode_opts(
    compression = compression,
    icc = icc,
    exif = exif,
    srgb = if (is.null(srgb)) -1L else srgb
  )
  encode_image(px, "png", opts, file)
}

#' @describeIn pix_write QOI, 8-bit RGB or RGBA; grey widens to RGB.
#' @param colourspace The QOI header's colourspace byte: `"srgb"` or
#'   `"linear"`. It is a label only; pixels are written as given.
#' @export
pix_write_qoi <- function(x, file = NULL, colourspace = c("srgb", "linear")) {
  colourspace <- match_arg(colourspace, c("srgb", "linear"), "colourspace")
  # 16-bit input is refused in C: QOI is 8-bit.
  px <- prepare_pixels(x, NULL)
  opts <- encode_opts(colourspace = as.integer(colourspace == "linear"))
  encode_image(px, "qoi", opts, file)
}

#' @describeIn pix_write JPEG, 8-bit grey or RGB through libjpeg-turbo, with
#'   optimised Huffman tables, an optional ICC profile (`APP2`) and EXIF
#'   block (`APP1`). An alpha channel must be fully opaque, since JPEG cannot
#'   store transparency; 16-bit samples are rounded to 8 bits.
#' @param quality For JPEG, 1 to 100 on libjpeg's scale (`90` here means
#'   what it means to `jpeg::writeJPEG(quality = 0.9)`). For WebP, 0 to 100;
#'   with `lossless = TRUE` it trades speed for size instead.
#' @param subsampling JPEG chroma subsampling: `"4:2:0"`, `"4:2:2"` or
#'   `"4:4:4"`.
#' @param progressive `TRUE` writes a progressive JPEG.
#' @export
pix_write_jpeg <- function(
  x,
  file = NULL,
  quality = 90L,
  subsampling = "4:2:0",
  progressive = FALSE,
  icc = NULL,
  exif = NULL
) {
  quality <- check_choice_int(quality, 1:100, "quality", FALSE)
  subsampling <- match_arg(
    subsampling,
    c("4:4:4", "4:2:2", "4:2:0"),
    "subsampling"
  )
  check_flag(progressive, "progressive")
  check_raw_or_null(icc, "icc")
  check_raw_or_null(exif, "exif")
  px <- prepare_pixels(x, 8L)
  opts <- encode_opts(
    icc = icc,
    exif = exif,
    quality = quality,
    subsampling = match(subsampling, c("4:4:4", "4:2:2", "4:2:0")) - 1L,
    progressive = progressive
  )
  encode_image(px, "jpeg", opts, file)
}

#' @describeIn pix_write WebP through libwebp, lossy or lossless, RGB or
#'   RGBA (grey widens to RGB), with an optional ICC profile and EXIF block
#'   in zupix's own `VP8X` container. 16-bit samples are rounded to 8 bits.
#' @param lossless `TRUE` writes lossless WebP: the pixels read back exactly.
#' @param method WebP's speed and size trade-off, 0 (fastest) to 6
#'   (smallest).
#' @export
pix_write_webp <- function(
  x,
  file = NULL,
  quality = 75,
  lossless = FALSE,
  method = 4L,
  icc = NULL,
  exif = NULL
) {
  if (
    !is.numeric(quality) ||
      length(quality) != 1L ||
      is.na(quality) ||
      quality < 0 ||
      quality > 100
  ) {
    zpx_input_error("quality", "`quality` must be a number from 0 to 100.")
  }
  check_flag(lossless, "lossless")
  method <- check_choice_int(method, 0:6, "method", FALSE)
  check_raw_or_null(icc, "icc")
  check_raw_or_null(exif, "exif")
  px <- prepare_pixels(x, 8L)
  opts <- encode_opts(
    icc = icc,
    exif = exif,
    quality = as.double(quality),
    lossless = lossless,
    method = method
  )
  encode_image(px, "webp", opts, file)
}

# The options list zpx_r_encode() reads, by position. Each writer sets the
# slots its format uses; the defaults only fill the slots it ignores.
encode_opts <- function(
  compression = 6L,
  icc = NULL,
  exif = NULL,
  srgb = -1L,
  colourspace = 0L,
  quality = 90,
  subsampling = 2L,
  progressive = FALSE,
  lossless = FALSE,
  method = 4L
) {
  list(
    compression,
    icc,
    exif,
    srgb,
    colourspace,
    quality,
    subsampling,
    progressive,
    lossless,
    method
  )
}

check_flag <- function(x, arg, call = sys.call(-1L)) {
  if (!isTRUE(x) && !isFALSE(x)) {
    zpx_input_error(
      arg,
      sprintf("`%s` must be TRUE or FALSE.", arg),
      call = call
    )
  }
}

encode_image <- function(px, format, opts, file, call = sys.call(-1L)) {
  if (
    !is.null(file) &&
      (!is.character(file) || length(file) != 1L || is.na(file))
  ) {
    zpx_input_error(
      "file",
      "`file` must be a single path or NULL.",
      call = call
    )
  }
  res <- .Call(
    zpx_r_encode,
    px$pixels,
    px$mode,
    px$dims,
    px$stored,
    px$target,
    match(format, zpx_formats),
    opts
  )
  if (inherits(res, "zupix_failure")) {
    zpx_raise_failure(res, format, call = call)
  }
  if (is.null(file)) {
    return(res)
  }
  ok <- tryCatch(
    {
      writeBin(res, file)
      TRUE
    },
    error = function(e) conditionMessage(e),
    warning = function(w) conditionMessage(w)
  )
  if (!isTRUE(ok)) {
    zpx_abort("io", sprintf("Can't write %s: %s", file, ok), call = call)
  }
  invisible(file)
}

# The image as the C encoder takes it: the caller's own vector (no copy),
# how to read it, its dims (height, width, channels) and depths. Missing,
# non-integer and out-of-range samples are refused in C, in the pass that
# converts them, rather than by whole-array passes here.
prepare_pixels <- function(x, bits, call = sys.call(-1L)) {
  if (inherits(x, "nativeRaster")) {
    if (!is.null(bits) && bits != 8L) {
      zpx_input_error("bits", "A nativeRaster is 8-bit.", call = call)
    }
    d <- dim(x)
    if (!is.integer(x) || length(d) != 2L || any(d < 1L)) {
      zpx_input_error(
        "x",
        "A nativeRaster must be an integer matrix with at least one pixel.",
        call = call
      )
    }
    return(list(
      pixels = x,
      mode = 0L,
      dims = c(d[[1L]], d[[2L]], 4L),
      stored = 8L,
      target = 8L
    ))
  }
  d <- dim(x)
  if (
    !((is.double(x) || is.integer(x)) && (length(d) == 2L || length(d) == 3L))
  ) {
    zpx_input_error(
      "x",
      "`x` must be a nativeRaster, or a numeric matrix or 3-dimensional array.",
      call = call
    )
  }
  dims <- c(d[[1L]], d[[2L]], if (length(d) == 3L) d[[3L]] else 1L)
  if (
    dims[[3L]] < 1L || dims[[3L]] > 4L || dims[[1L]] < 1L || dims[[2L]] < 1L
  ) {
    zpx_input_error(
      "x",
      "`x` must have 1 to 4 channels and at least one pixel.",
      call = call
    )
  }
  stored <- attr(x, "bits")
  if (
    !is.null(stored) &&
      !identical(as.integer(stored), 8L) &&
      !identical(as.integer(stored), 16L)
  ) {
    zpx_input_error(
      "x",
      "`x`'s `bits` attribute must be 8L or 16L.",
      call = call
    )
  }
  unit <- is.double(x) && is.null(stored)
  list(
    pixels = x,
    mode = if (unit) 1L else 2L,
    dims = as.integer(dims),
    stored = if (is.null(stored)) NA_integer_ else as.integer(stored),
    target = if (is.null(bits)) {
      if (unit) 8L else NA_integer_
    } else {
      as.integer(bits)
    }
  )
}

check_raw_or_null <- function(x, arg, call = sys.call(-1L)) {
  if (!is.null(x) && !is.raw(x)) {
    zpx_input_error(
      arg,
      sprintf("`%s` must be a raw vector or NULL.", arg),
      call = call
    )
  }
}
