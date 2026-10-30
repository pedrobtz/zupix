# Design §8: every condition inherits from zupix_error; tests assert class.

test_that("conditions carry zupix_error and their own class", {
  err <- expect_error(pix_read(charToRaw("nope")), class = "zupix_error")
  expect_s3_class(err, c("zupix_format_error", "zupix_error", "error"))
})

test_that("a truncated PNG is a decode error, never a partial image", {
  p <- make_png(samples_for(8L, 8L, 3L, 255L), 8L, 2L)
  for (cut in c(40L, length(p) - 20L, length(p) - 13L)) {
    expect_error(pix_read(p[seq_len(cut)]), class = "zupix_decode_error")
  }
})

test_that("a corrupt PNG is a decode error with the decoder's detail", {
  p <- make_png(samples_for(4L, 4L, 3L, 255L), 4L, 2L)
  idat <- grepRaw("IDAT", p)
  p[idat + 6L] <- xor(p[idat + 6L], as.raw(0xff))
  err <- expect_error(pix_read(p), class = "zupix_decode_error")
  expect_identical(err$format, "png")
  expect_type(err$detail, "character")
})

test_that("a chunk length past the end of the input is a decode error", {
  p <- make_png(matrix(0L), 1L, 0L)
  # Claim a 2^31 - 1 byte chunk right after IHDR.
  p <- c(p[1:33], as.raw(c(0x7f, 0xff, 0xff, 0xff)), charToRaw("tEXt"))
  expect_error(pix_read(p), class = "zupix_decode_error")
})

test_that("a truncated QOI is a decode error", {
  q <- make_qoi(array(7L, c(3L, 3L, 3L)))
  expect_error(pix_read(q[1:20]), class = "zupix_decode_error")
})

test_that("bad arguments are input errors", {
  p <- make_png(matrix(0L), 1L, 0L)
  expect_error(pix_read(1:3), class = "zupix_input_error")
  expect_error(pix_read(c("a", "b")), class = "zupix_input_error")
  expect_error(pix_read(p, as = "raster"), class = "zupix_input_error")
  expect_error(pix_read(p, bits = 12L), class = "zupix_input_error")
  expect_error(pix_read(p, channels = 5L), class = "zupix_input_error")
  expect_error(pix_read(p, format = "gif"), class = "zupix_input_error")
  err <- expect_error(
    pix_read(p, as = "double", channels = 0L),
    class = "zupix_input_error"
  )
  expect_identical(err$arg, "channels")
})

test_that("a missing file is an I/O error", {
  missing <- file.path(withr::local_tempdir(), "nope.png")
  expect_error(pix_read(missing), class = "zupix_io_error")
  expect_error(pix_format(missing), class = "zupix_io_error")
})

test_that("paths, raw vectors and connections give the same image", {
  p <- make_png(samples_for(3L, 3L, 4L, 255L), 3L, 6L)
  f <- withr::local_tempfile(fileext = ".png")
  writeBin(p, f)
  from_raw <- pix_read(p, as = "integer")
  expect_identical(pix_read(f, as = "integer"), from_raw)
  con <- file(f, "rb")
  withr::defer(close(con))
  expect_identical(pix_read(con, as = "integer"), from_raw)
})
