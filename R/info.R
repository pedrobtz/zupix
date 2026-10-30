#' Read an image's header and metadata
#'
#' Reports what an image is without decoding its pixels: format, size, depth,
#' colour type, transparency, interlacing, animation, density, EXIF
#' orientation, PNG colour chunks, and whether ICC and EXIF data are present.
#' The colour information is reported, never applied.
#'
#' @param x File paths (one row each), a raw vector holding one file's bytes,
#'   or a connection, which is read whole.
#' @inheritParams pix_read
#' @return A data frame with one row per image and columns:
#'   * `format`: `"png"`, `"jpeg"`, `"webp"` or `"qoi"`.
#'   * `width`, `height`: in pixels, as stored (before any EXIF rotation).
#'   * `bits`: the stored sample depth: 1, 2, 4, 8 or 16 for PNG; the
#'     precision for JPEG (8, or 12 which zupix does not decode); 8 otherwise.
#'   * `colour_type`: `"grey"`, `"grey_alpha"`, `"rgb"`, `"rgba"`,
#'     `"palette"`, `"ycbcr"`, `"cmyk"` or `"ycck"`, as stored. JPEG and lossy
#'     WebP store YCbCr; CMYK and YCCK JPEG decode to RGB.
#'   * `alpha`: whether the image has transparency, including PNG `tRNS`.
#'   * `interlaced`: Adam7 PNG or progressive JPEG.
#'   * `animated`: APNG or animated WebP; [pix_read()] decodes the first
#'     frame.
#'   * `density_x`, `density_y`, `density_unit`: from PNG `pHYs` (unit 1:
#'     pixels per metre) or the JPEG JFIF header (1: per inch, 2: per
#'     centimetre); unit 0 gives only the aspect ratio. `NA` when absent.
#'   * `orientation`: the EXIF orientation, 1 to 8, or `NA`. See
#'     [pix_orient()].
#'   * `gamma`, `srgb`: PNG `gAMA` (the stored value over 100,000) and the
#'     `sRGB` rendering intent, or `NA`.
#'   * `chrm`: a list column, PNG `cHRM`'s eight chromaticities (white, red,
#'     green, blue; x then y), or `NULL`.
#'   * `cicp`: a list column, PNG `cICP`'s four integers (colour primaries,
#'     transfer function, matrix coefficients, full-range flag), or `NULL`.
#'   * `icc`, `exif`: whether an ICC profile or EXIF data is present; see
#'     [pix_icc()] and [pix_exif()].
#'   * `qoi_linear`: for QOI, whether the header declares linear channels
#'     rather than sRGB; `NA` for other formats.
#' @export
#' @examples
#' f <- system.file("extdata", "gradient.png", package = "zupix")
#' pix_info(f)
pix_info <- function(x, format = "auto", limits = pix_limits()) {
  format <- match_arg(format, c("auto", zpx_formats), "format")
  lim <- check_limits(limits)
  call <- sys.call()
  inputs <- if (is.character(x) && length(x) != 1L) as.list(x) else list(x)
  if (length(inputs) == 0L) {
    return(info_frame(list()))
  }
  rows <- lapply(inputs, function(one) {
    bytes <- read_input(one, lim[[3L]], call = call)
    info_one(bytes, format, lim, call)
  })
  info_frame(rows)
}

info_one <- function(bytes, format, lim, call) {
  check_format(bytes, format, call)
  res <- .Call(zpx_r_info, bytes, lim)
  if (inherits(res, "zupix_failure")) {
    zpx_raise_failure(res, sniffed_format(bytes), call = call)
  }
  res$format <- zpx_formats[[res$format]]
  res
}

info_frame <- function(rows) {
  col <- function(name, type) {
    vapply(rows, function(r) r[[name]], type)
  }
  out <- data.frame(
    format = col("format", ""),
    width = col("width", 0),
    height = col("height", 0),
    bits = col("bits", 0L),
    colour_type = col("colour_type", ""),
    alpha = col("alpha", NA),
    interlaced = col("interlaced", NA),
    animated = col("animated", NA),
    density_x = col("density_x", 0),
    density_y = col("density_y", 0),
    density_unit = col("density_unit", 0L),
    orientation = col("orientation", 0L),
    gamma = col("gamma", 0),
    srgb = col("srgb", 0L),
    icc = col("icc", NA),
    exif = col("exif", NA),
    qoi_linear = col("qoi_linear", NA),
    stringsAsFactors = FALSE
  )
  out$chrm <- lapply(rows, function(r) r$chrm)
  out$cicp <- lapply(rows, function(r) r$cicp)
  out[c(
    "format",
    "width",
    "height",
    "bits",
    "colour_type",
    "alpha",
    "interlaced",
    "animated",
    "density_x",
    "density_y",
    "density_unit",
    "orientation",
    "gamma",
    "srgb",
    "chrm",
    "cicp",
    "icc",
    "exif",
    "qoi_linear"
  )]
}

#' Extract an image's ICC profile or EXIF data
#'
#' `pix_icc()` returns the ICC profile embedded in a PNG (`iCCP`, inflated),
#' JPEG (`APP2` segments, reassembled in sequence order) or WebP (`ICCP`).
#' `pix_exif()` returns the EXIF block of a JPEG (`APP1`), PNG (`eXIf`) or
#' WebP (`EXIF`), from its TIFF header onward. Neither is interpreted or
#' applied; pass the profile to a colour-management package to use it.
#'
#' @inheritParams pix_read
#' @return A raw vector, or `NULL` when the image has none.
#' @export
#' @examples
#' f <- system.file("extdata", "gradient.png", package = "zupix")
#' pix_icc(f)
#' pix_exif(f)
pix_icc <- function(x, format = "auto", limits = pix_limits()) {
  metadata_bytes(x, format, limits, "icc", sys.call())
}

#' @rdname pix_icc
#' @export
pix_exif <- function(x, format = "auto", limits = pix_limits()) {
  metadata_bytes(x, format, limits, "exif", sys.call())
}

metadata_bytes <- function(x, format, limits, what, call) {
  format <- match_arg(format, c("auto", zpx_formats), "format", call = call)
  lim <- check_limits(limits, call = call)
  bytes <- read_input(x, lim[[3L]], call = call)
  check_format(bytes, format, call)
  # Each .Call names its routine, so R CMD check can verify it.
  res <- if (what == "icc") {
    .Call(zpx_r_icc, bytes, lim)
  } else {
    .Call(zpx_r_exif, bytes, lim)
  }
  if (inherits(res, "zupix_failure")) {
    zpx_raise_failure(res, sniffed_format(bytes), call = call)
  }
  res
}

# A named format must match the signature (design §6.1).
check_format <- function(bytes, format, call) {
  found <- sniffed_format(bytes)
  if (is.na(found)) {
    zpx_abort(
      "format",
      "The input is not a PNG, JPEG, WebP or QOI image.",
      format = NA_character_,
      detail = NA_character_,
      call = call
    )
  }
  if (format != "auto" && format != found) {
    zpx_abort(
      "format",
      sprintf(
        "`format` is \"%s\" but the input is %s.",
        format,
        toupper(found)
      ),
      format = found,
      detail = NA_character_,
      call = call
    )
  }
  invisible(found)
}
