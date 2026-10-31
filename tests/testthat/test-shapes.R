# Design §6.2: the three shapes, depth and channel rules, for PNG and QOI.

test_that("integer output keeps every PNG colour type's samples and depth", {
  for (case in png_cases()) {
    max <- 2L^case$depth - 1L
    s <- samples_for(3L, 5L, case$per, max)
    img <- pix_read(make_png(s, 5L, case$ct, case$depth), as = "integer")

    bits <- if (case$depth == 16L) 16L else 8L
    want <- expected_array(scale_to_8(s, case$depth), 3L, 5L, case$per)
    expect_identical(as.vector(img), as.vector(want), info = deparse(case))
    expect_identical(
      dim(img),
      if (case$channels == 1L) c(3L, 5L) else c(3L, 5L, case$channels)
    )
    expect_identical(attr(img, "bits"), bits)
  }
})

test_that("double output is the integer samples over 2^bits - 1", {
  for (case in png_cases()) {
    s <- samples_for(2L, 4L, case$per, 2L^case$depth - 1L)
    p <- make_png(s, 4L, case$ct, case$depth)
    int <- pix_read(p, as = "integer")
    dbl <- pix_read(p, as = "double")
    expect_type(dbl, "double")
    expect_null(attr(dbl, "bits"))
    expect_equal(as.vector(dbl), as.vector(int) / (2^attr(int, "bits") - 1))
  }
})

test_that("a palette becomes RGB, or RGBA with tRNS", {
  palette <- c(255, 0, 0, 0, 255, 0, 0, 0, 255)
  idx <- matrix(c(0L, 1L, 2L, 1L, 0L, 2L), nrow = 2L, byrow = TRUE)

  rgb <- pix_read(make_png(idx, 3L, 3L, palette = palette), as = "integer")
  expect_identical(dim(rgb), c(2L, 3L, 3L))
  expect_identical(rgb[1, , 1], c(255L, 0L, 0L))
  expect_identical(rgb[2, , 3], c(0L, 0L, 255L))

  rgba <- pix_read(
    make_png(idx, 3L, 3L, palette = palette, trns = c(0, 128)),
    as = "integer"
  )
  expect_identical(dim(rgba), c(2L, 3L, 4L))
  expect_identical(rgba[1, , 4], c(0L, 128L, 255L))
})

test_that("tRNS gives grey an alpha channel and RGB an RGBA one", {
  grey <- matrix(c(10L, 20L, 30L, 40L), nrow = 2L)
  # Rows of `grey` are image rows: 10 30 / 20 40. Only 20 is transparent.
  g <- pix_read(make_png(grey, 2L, 0L, trns = c(0, 20)), as = "integer")
  expect_identical(dim(g), c(2L, 2L, 2L))
  expect_identical(g[,, 2], matrix(c(255L, 0L, 255L, 255L), 2L))

  g16 <- pix_read(
    make_png(grey * 1000L, 2L, 0L, 16L, trns = be32(20000)[3:4]),
    as = "integer"
  )
  expect_identical(dim(g16), c(2L, 2L, 2L))
  expect_identical(g16[,, 2], matrix(c(65535L, 0L, 65535L, 65535L), 2L))

  rgb <- matrix(c(1L, 2L, 3L, 4L, 5L, 6L), nrow = 1L)
  r <- pix_read(
    make_png(rgb, 2L, 2L, trns = c(0, 4, 0, 5, 0, 6)),
    as = "integer"
  )
  expect_identical(dim(r), c(1L, 2L, 4L))
  expect_identical(r[1, , 4], c(255L, 0L))
})

test_that("native output is a png-compatible nativeRaster", {
  s <- samples_for(3L, 4L, 4L, 255L)
  img <- pix_read(make_png(s, 4L, 6L))
  expect_s3_class(img, "nativeRaster")
  expect_identical(dim(img), c(3L, 4L))
  expect_identical(attr(img, "channels"), 4L)
  # Row-major, one RGBA pixel per integer, R in the low byte: element k is
  # pixel k in reading order, whatever R's [i, j] would suggest.
  pack <- function(px) {
    v <- sum(px * c(1, 2^8, 2^16, 2^24))
    as.integer(if (v >= 2^31) v - 2^32 else v)
  }
  expect_identical(img[[2]], pack(s[1, 5:8]))
  expect_identical(img[[12]], pack(s[3, 13:16]))
})

test_that("native output rounds 16-bit samples to the nearest 8-bit value", {
  # round(v / 257): 257k + 128 rounds down, 257k + 129 up.
  v <- c(0L, 65535L, 257L * 128L + 128L, 257L * 128L + 129L)
  s <- matrix(as.vector(rbind(v, v, v, 65535L)), nrow = 1L)
  img <- pix_read(make_png(s, 4L, 6L, 16L))
  red <- bitwAnd(as.vector(img), 255L)
  expect_identical(red, c(0L, 255L, 128L, 129L))
})

test_that("bits forces the depth in both directions", {
  s <- samples_for(2L, 2L, 3L, 255L)
  p8 <- make_png(s, 2L, 2L)
  up <- pix_read(p8, as = "integer", bits = 16L)
  expect_identical(attr(up, "bits"), 16L)
  expect_identical(
    as.vector(up),
    as.vector(pix_read(p8, as = "integer")) * 257L
  )

  s16 <- s * 257L
  down <- pix_read(make_png(s16, 2L, 2L, 16L), as = "integer", bits = 8L)
  expect_identical(attr(down, "bits"), 8L)
  expect_identical(as.vector(down), as.vector(expected_array(s, 2L, 2L, 3L)))
})

test_that("channels adds grey to RGB and an opaque alpha, never removes", {
  grey <- matrix(c(10L, 20L, 30L, 40L), nrow = 2L)
  p <- make_png(grey, 2L, 0L)

  rgb <- pix_read(p, as = "integer", channels = 3L)
  expect_identical(dim(rgb), c(2L, 2L, 3L))
  for (k in 1:3) {
    expect_identical(rgb[,, k], grey)
  }

  ga <- pix_read(p, as = "integer", channels = 2L)
  expect_identical(ga[,, 1], grey)
  expect_identical(ga[,, 2], matrix(255L, 2L, 2L))

  rgba16 <- pix_read(make_png(grey, 2L, 0L, 16L), as = "integer", channels = 4L)
  expect_identical(rgba16[,, 4], matrix(65535L, 2L, 2L))

  rgb_png <- make_png(samples_for(2L, 2L, 3L, 255L), 2L, 2L)
  expect_error(
    pix_read(rgb_png, as = "integer", channels = 1L),
    class = "zupix_input_error"
  )
  expect_error(
    pix_read(rgb_png, as = "double", channels = 2L),
    class = "zupix_input_error"
  )
})

test_that("native takes no bits or channels other than 8 and 4", {
  p <- make_png(samples_for(1L, 1L, 3L, 255L), 1L, 2L)
  expect_s3_class(pix_read(p, bits = 8L, channels = 4L), "nativeRaster")
  expect_error(pix_read(p, bits = 16L), class = "zupix_input_error")
  expect_error(pix_read(p, channels = 3L), class = "zupix_input_error")
})

test_that("QOI decodes to the same shapes", {
  rgb <- array(as.integer((1:24 * 11L) %% 256L), c(2L, 4L, 3L))
  img <- pix_read(make_qoi(rgb), as = "integer")
  expect_identical(attr(img, "bits"), 8L)
  attr(img, "bits") <- NULL
  expect_identical(img, rgb)

  rgba <- array(as.integer((1:32 * 7L) %% 256L), c(2L, 4L, 4L))
  expect_identical(
    as.vector(pix_read(make_qoi(rgba), as = "integer")),
    as.vector(rgba)
  )
  expect_equal(pix_read(make_qoi(rgba), as = "double"), rgba / 255)
  expect_s3_class(pix_read(make_qoi(rgba)), "nativeRaster")
})

test_that("png::readPNG() agrees exactly on 8-bit files", {
  skip_if_not_installed("png")
  for (case in png_cases()[vapply(
    png_cases(),
    function(x) x$depth == 8L,
    NA
  )]) {
    p <- make_png(samples_for(3L, 4L, case$per, 255L), 4L, case$ct)
    expect_identical(pix_read(p, as = "double"), png::readPNG(p))
    expect_identical(pix_read(p), png::readPNG(p, native = TRUE))
  }
})

test_that("png::readPNG() agrees exactly on 16-bit files as doubles", {
  skip_if_not_installed("png")
  for (case in png_cases()[vapply(
    png_cases(),
    function(x) x$depth == 16L,
    NA
  )]) {
    p <- make_png(samples_for(3L, 4L, case$per, 65535L), 4L, case$ct, 16L)
    expect_identical(pix_read(p, as = "double"), png::readPNG(p))
  }
})

test_that("qoi::readQOI() agrees exactly", {
  skip_if_not_installed("qoi")
  # Through a file: qoi 0.1.0's readQOI() crashes R on a raw vector.
  f <- withr::local_tempfile(fileext = ".qoi")
  for (ch in 3:4) {
    img <- array(as.integer((seq_len(3 * 5 * ch) * 13L) %% 256L), c(3L, 5L, ch))
    writeBin(make_qoi(img), f)
    expect_identical(
      as.vector(pix_read(f, as = "integer")),
      as.vector(qoi::readQOI(f))
    )
  }
})

test_that("1-, 2- and 4-bit palettes become 8-bit RGB", {
  palette <- c(0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255)
  for (depth in c(1L, 2L, 4L)) {
    n <- min(4L, 2L^depth)
    idx <- matrix(rep_len(seq_len(n) - 1L, 6L), nrow = 2L)
    img <- pix_read(
      make_png(idx, 3L, 3L, depth, palette = palette[seq_len(3L * n)]),
      as = "integer"
    )
    expect_identical(attr(img, "bits"), 8L)
    expect_identical(dim(img), c(2L, 3L, 3L))
    pal <- matrix(palette, nrow = 3L)
    expect_identical(img[1, 1, ], as.integer(pal[, idx[1, 1] + 1L]))
    expect_identical(img[2, 3, ], as.integer(pal[, idx[2, 3] + 1L]))
  }
})

test_that("channels that would drop alpha are refused (design D10)", {
  ga <- random_image(3L, 4L, 2L, 8L)
  png <- pix_write_png(ga)
  expect_error(
    pix_read(png, as = "integer", channels = 3L),
    class = "zupix_input_error"
  )
  expect_error(
    pix_read(png, as = "integer", channels = 1L),
    class = "zupix_input_error"
  )
  rgba <- pix_read(png, as = "integer", channels = 4L)
  expect_identical(rgba[,, 4], ga[,, 2])
})
