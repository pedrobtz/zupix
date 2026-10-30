# Design §6.5: limits checked on declared sizes, before allocation.

test_that("a tiny file declaring 10^6 x 10^6 fails before allocating", {
  p <- declared_png(1e6, 1e6)
  expect_lt(length(p), 60L)
  err <- expect_error(pix_read(p), class = "zupix_limit_error")
  expect_identical(err$limit, "max_side")
  expect_identical(err$value, 1e6)
  expect_identical(err$cap, 65535)
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
  expect_output(print(pix_limits()), "max_pixels")
})
