# Design §6.3: orientation is reported, and applied only on request.

test_that("pix_orient() applies each EXIF orientation to a matrix", {
  m <- matrix(1:6, nrow = 2L, byrow = TRUE) # 1 2 3 / 4 5 6
  expect_identical(pix_orient(m, 1L), m)
  expect_identical(
    pix_orient(m, 2L),
    matrix(c(3L, 2L, 1L, 6L, 5L, 4L), 2L, byrow = TRUE)
  )
  expect_identical(
    pix_orient(m, 3L),
    matrix(c(6L, 5L, 4L, 3L, 2L, 1L), 2L, byrow = TRUE)
  )
  expect_identical(
    pix_orient(m, 4L),
    matrix(c(4L, 5L, 6L, 1L, 2L, 3L), 2L, byrow = TRUE)
  )
  expect_identical(
    pix_orient(m, 5L),
    matrix(c(1L, 4L, 2L, 5L, 3L, 6L), 3L, byrow = TRUE)
  )
  # 6: 90 degrees clockwise.
  expect_identical(
    pix_orient(m, 6L),
    matrix(c(4L, 1L, 5L, 2L, 6L, 3L), 3L, byrow = TRUE)
  )
  expect_identical(
    pix_orient(m, 7L),
    matrix(c(6L, 3L, 5L, 2L, 4L, 1L), 3L, byrow = TRUE)
  )
  # 8: 90 degrees anticlockwise.
  expect_identical(
    pix_orient(m, 8L),
    matrix(c(3L, 6L, 2L, 5L, 1L, 4L), 3L, byrow = TRUE)
  )
  expect_identical(pix_orient(m, NA), m)
})

test_that("every orientation is undone by its inverse", {
  inverse <- c(1L, 2L, 3L, 4L, 5L, 8L, 7L, 6L)
  a <- array(1:24, c(2L, 3L, 4L))
  for (o in 1:8) {
    expect_identical(pix_orient(pix_orient(a, o), inverse[[o]]), a)
  }
})

test_that("arrays, integer images and nativeRasters orient alike", {
  s <- samples_for(2L, 3L, 4L, 255L)
  p <- make_png(s, 3L, 6L)
  int <- pix_read(p, as = "integer")
  nat <- pix_read(p)
  for (o in c(2L, 5L, 6L, 8L)) {
    oi <- pix_orient(int, o)
    expect_identical(attr(oi, "bits"), 8L)
    on <- pix_orient(nat, o)
    expect_s3_class(on, "nativeRaster")
    expect_identical(dim(on), dim(oi)[1:2])
    # The reoriented nativeRaster holds the reoriented pixels.
    red <- bitwAnd(as.vector(t(matrix(unclass(on), dim(on)[2]))), 255L)
    expect_identical(red, as.vector(oi[,, 1]))
  }
})

test_that("pix_read(orient = TRUE) applies the EXIF orientation", {
  jpg <- jpeg_with(fixture("rgb.jpg"), jpeg_exif(exif_block(6L)))
  stored <- pix_read(jpg, as = "integer")
  expect_identical(dim(stored), c(12L, 16L, 3L))
  turned <- pix_read(jpg, as = "integer", orient = TRUE)
  expect_identical(dim(turned), c(16L, 12L, 3L))
  expect_identical(turned, pix_orient(stored, 6L))
  expect_identical(dim(pix_read(jpg, orient = TRUE)), c(16L, 12L))
})

test_that("pix_orient() and orient reject bad arguments", {
  expect_error(pix_orient(matrix(1), 9L), class = "zupix_input_error")
  expect_error(pix_orient(1:3, 2L), class = "zupix_input_error")
  expect_error(
    pix_read(fixture("rgb.jpg"), orient = NA),
    class = "zupix_input_error"
  )
})

test_that("pix_orient() keeps the animated attribute", {
  img <- random_image(2L, 3L, 3L, 8L)
  attr(img, "animated") <- TRUE
  expect_true(attr(pix_orient(img, 6L), "animated"))
})
