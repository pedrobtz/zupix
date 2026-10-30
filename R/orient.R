#' Apply an EXIF orientation
#'
#' Rotates or flips an image the way its EXIF orientation says it should be
#' displayed. The operation is lossless: pixels are moved, never resampled.
#' [pix_read()] returns pixels as stored unless `orient = TRUE`, so the
#' orientation [pix_info()] reports and the pixels returned always agree.
#'
#' @param img An image as [pix_read()] returns it: a `nativeRaster`, a
#'   matrix, or a `height x width x channels` array.
#' @param orientation The EXIF orientation, 1 to 8: 1 as stored, 2 mirrored
#'   left to right, 3 rotated 180 degrees, 4 mirrored top to bottom, 5
#'   transposed, 6 rotated 90 degrees clockwise, 7 transverse, 8 rotated 90
#'   degrees anticlockwise. `NA` leaves the image as it is.
#' @return `img`, reoriented, with its class and `bits` attribute kept.
#' @export
#' @examples
#' f <- system.file("extdata", "gradient.png", package = "zupix")
#' img <- pix_read(f, as = "integer")
#' dim(img)
#' dim(pix_orient(img, 6L))
pix_orient <- function(img, orientation) {
  if (
    length(orientation) != 1L ||
      !(is.na(orientation) ||
        (is.numeric(orientation) && orientation %in% 1:8))
  ) {
    zpx_input_error(
      "orientation",
      "`orientation` must be a single integer from 1 to 8, or NA."
    )
  }
  native <- inherits(img, "nativeRaster")
  d <- dim(img)
  if (!(is.matrix(img) || native || (is.array(img) && length(d) == 3L))) {
    zpx_input_error(
      "img",
      "`img` must be a nativeRaster, a matrix or a three-dimensional array."
    )
  }
  if (is.na(orientation) || orientation == 1L) {
    return(img)
  }
  attrs <- attributes(img)[c("class", "channels", "bits")]
  attrs <- attrs[!vapply(attrs, is.null, NA)]

  if (native) {
    # A nativeRaster holds pixels row-major: its data read as a width x
    # height matrix and transposed is the image as R indexes it.
    a <- t(matrix(unclass(img), nrow = d[[2L]], ncol = d[[1L]]))
  } else {
    a <- unclass(img)
    attr(a, "bits") <- NULL
  }
  three <- length(dim(a)) == 3L
  h <- dim(a)[[1L]]
  w <- dim(a)[[2L]]
  flip_x <- function(a) {
    if (three) a[, w:1, , drop = FALSE] else a[, w:1, drop = FALSE]
  }
  flip_y <- function(a) {
    if (three) a[h:1, , , drop = FALSE] else a[h:1, , drop = FALSE]
  }
  transpose <- function(a) if (three) aperm(a, c(2L, 1L, 3L)) else t(a)

  a <- switch(
    orientation,
    a,
    flip_x(a),
    flip_y(flip_x(a)),
    flip_y(a),
    transpose(a),
    transpose(flip_y(a)),
    transpose(flip_y(flip_x(a))),
    transpose(flip_x(a))
  )

  if (native) {
    nd <- dim(a)
    a <- as.vector(t(a))
    dim(a) <- nd
  }
  for (nm in names(attrs)) {
    attr(a, nm) <- attrs[[nm]]
  }
  a
}
