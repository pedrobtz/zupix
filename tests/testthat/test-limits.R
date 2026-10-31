# Design §6.5: limits checked on declared sizes, before allocation.

test_that("a tiny file declaring 10^6 x 10^6 fails before allocating", {
  p <- declared_png(1e6, 1e6)
  expect_lt(length(p), 60L)
  err <- expect_error(pix_read(p), class = "zupix_limit_error")
  expect_identical(err$limit, "max_side")
  expect_identical(err$value, 1e6)
  expect_identical(err$cap, 65535)
})

test_that("max_side applies to the height as well as the width", {
  err <- expect_error(
    pix_read(declared_png(1, 70000)),
    class = "zupix_limit_error"
  )
  expect_identical(err$limit, "max_side")
  expect_identical(err$value, 70000)
  expect_identical(err$cap, 65535)

  tall <- make_png(samples_for(5L, 2L, 1L, 255L), 2L, 0L)
  err <- expect_error(
    pix_read(tall, limits = pix_limits(max_side = 4)),
    class = "zupix_limit_error"
  )
  expect_identical(c(err$value, err$cap), c(5, 4))
  expect_identical(
    dim(pix_read(tall, as = "integer", limits = pix_limits(max_side = 5))),
    c(5L, 2L)
  )
})

test_that("max_pixels is checked on width times height", {
  p <- declared_png(30000, 30000)
  err <- expect_error(pix_read(p), class = "zupix_limit_error")
  expect_identical(err$limit, "max_pixels")
  expect_identical(err$value, 9e8)
  expect_identical(err$cap, 1e8)

  err <- expect_error(
    pix_read(
      make_png(samples_for(4L, 4L, 1L, 255L), 4L, 0L),
      limits = pix_limits(max_pixels = 15)
    ),
    class = "zupix_limit_error"
  )
  expect_identical(err$limit, "max_pixels")
})

test_that("max_bytes counts the result's size, which depends on `as`", {
  # 2000 x 2000 RGBA: 16 MB native, 128 MB as doubles (plus a 16 MB
  # working copy).
  p <- declared_png(2000, 2000)
  lim <- pix_limits(max_bytes = 5e7)
  err <- expect_error(
    pix_read(p, as = "double", limits = lim),
    class = "zupix_limit_error"
  )
  expect_identical(err$limit, "max_bytes")
  expect_gt(err$value, 1.28e8)
  expect_match(conditionMessage(err), "as = \"native\"", fixed = TRUE)
  # Within the limit natively, so the failure moves on to the missing pixels.
  expect_error(pix_read(p, limits = lim), class = "zupix_decode_error")
})

test_that("max_bytes counts the work buffer and the RGBA intermediate", {
  # 200 RGBA pixels: 800 bytes natively, 6,400 as doubles.
  p <- make_png(samples_for(10L, 20L, 4L, 255L), 20L, 6L)
  # The decoder's work buffer alone is checked first, before the result.
  err <- expect_error(
    pix_read(p, limits = pix_limits(max_bytes = 1)),
    class = "zupix_limit_error"
  )
  expect_identical(err$limit, "max_bytes")
  expect_identical(err$cap, 1)
  work <- err$value
  expect_gt(work, 1)
  expect_lt(work, 6400)

  # An array result also needs the row-major RGBA copy it is built from.
  err <- expect_error(
    pix_read(p, as = "double", limits = pix_limits(max_bytes = 6400 + work)),
    class = "zupix_limit_error"
  )
  expect_identical(err$value, 6400 + 800 + work)
  expect_identical(err$cap, 6400 + work)
  err <- expect_error(
    pix_read(p, as = "integer", limits = pix_limits(max_bytes = 3200 + work)),
    class = "zupix_limit_error"
  )
  expect_identical(err$value, 3200 + 800 + work)
  full <- pix_limits(max_bytes = 6400 + 800 + work)
  expect_identical(
    dim(pix_read(p, as = "double", limits = full)),
    c(10L, 20L, 4L)
  )
  # A nativeRaster is decoded in place, with no copy.
  native <- pix_read(p, limits = pix_limits(max_bytes = 800 + work))
  expect_s3_class(native, "nativeRaster")
})

test_that("max_bytes counts qoi.h's own buffer for QOI", {
  # 200 pixels: 800 bytes as a nativeRaster, and 800 in qoi.h's buffer.
  q <- make_qoi_runs(10L, 20L, c(1L, 2L, 3L))
  err <- expect_error(
    pix_read(q, limits = pix_limits(max_bytes = 799)),
    class = "zupix_limit_error"
  )
  expect_identical(c(err$value, err$cap), c(800, 799))
  err <- expect_error(
    pix_read(q, limits = pix_limits(max_bytes = 1599)),
    class = "zupix_limit_error"
  )
  expect_identical(c(err$value, err$cap), c(1600, 1599))
  expect_s3_class(
    pix_read(q, limits = pix_limits(max_bytes = 1600)),
    "nativeRaster"
  )
  # As doubles: 4,800 for the result, 800 for the RGBA copy, 800 for qoi.h.
  err <- expect_error(
    pix_read(q, as = "double", limits = pix_limits(max_bytes = 5599)),
    class = "zupix_limit_error"
  )
  expect_identical(err$value, 6400)
})

test_that("max_bytes caps the input read from a file or connection", {
  p <- make_png(samples_for(2L, 2L, 1L, 255L), 2L, 0L)
  f <- withr::local_tempfile(fileext = ".png")
  writeBin(p, f)
  lim <- pix_limits(max_bytes = length(p) - 1)

  err <- expect_error(pix_read(f, limits = lim), class = "zupix_limit_error")
  expect_identical(err$limit, "max_bytes")

  con <- file(f, "rb")
  withr::defer(close(con))
  expect_error(pix_read(con, limits = lim), class = "zupix_limit_error")
})

test_that("pix_limits() validates and takes session defaults from options", {
  expect_s3_class(pix_limits(), "zupix_limits")
  expect_identical(pix_limits()$max_side, 65535)
  expect_error(pix_limits(max_side = 0), class = "zupix_input_error")
  expect_error(pix_limits(max_pixels = 1.5), class = "zupix_input_error")
  expect_error(pix_limits(max_bytes = NA), class = "zupix_input_error")
  expect_error(pix_read(raw(), limits = list()), class = "zupix_input_error")

  withr::local_options(zupix.max_side = 3L)
  expect_identical(pix_limits()$max_side, 3)
  err <- expect_error(
    pix_read(make_png(samples_for(1L, 4L, 1L, 255L), 4L, 0L)),
    class = "zupix_limit_error"
  )
  expect_identical(err$cap, 3)
})

test_that("limits print", {
  withr::local_options(
    zupix.max_side = NULL,
    zupix.max_pixels = NULL,
    zupix.max_bytes = NULL,
    zupix.max_metadata = NULL
  )
  expect_snapshot(print(pix_limits()))
})
