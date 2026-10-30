# Design §6.1: formats come from signatures, never extensions.

test_that("pix_format() names each signature", {
  expect_identical(pix_format(make_png(matrix(0L), 1L, 0L)), "png")
  expect_identical(pix_format(as.raw(c(0xff, 0xd8, 0xff, 0xe0))), "jpeg")
  expect_identical(
    pix_format(c(charToRaw("RIFF"), as.raw(c(0, 0, 0, 0)), charToRaw("WEBP"))),
    "webp"
  )
  expect_identical(pix_format(make_qoi(array(0L, c(1L, 1L, 3L)))), "qoi")
  expect_identical(pix_format(charToRaw("GIF89a")), NA_character_)
  expect_identical(pix_format(raw()), NA_character_)
})

test_that("pix_format() reads a file's signature, not its extension", {
  f <- withr::local_tempfile(fileext = ".jpg")
  writeBin(make_qoi(array(0L, c(1L, 1L, 3L))), f)
  expect_identical(pix_format(f), "qoi")
  expect_identical(pix_read(f, as = "integer")[1, 1, ], c(0L, 0L, 0L))
})

test_that("a named format that disagrees with the signature is an error", {
  p <- make_png(matrix(0L), 1L, 0L)
  expect_s3_class(pix_read(p, format = "png"), "nativeRaster")
  err <- expect_error(pix_read(p, format = "qoi"), class = "zupix_format_error")
  expect_match(conditionMessage(err), "PNG")
})

test_that("an unknown signature is a format error", {
  expect_error(
    pix_read(charToRaw("GIF89a and more")),
    class = "zupix_format_error"
  )
  expect_error(pix_read(raw()), class = "zupix_format_error")
})

test_that("JPEG and WebP are recognised but not yet decoded", {
  jpeg <- as.raw(c(0xff, 0xd8, 0xff, 0xe0, 0, 16))
  expect_error(pix_read(jpeg), class = "zupix_unsupported_error")
})
