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

test_that("a QOI of runs decodes, and every cut past its header fails", {
  q <- make_qoi_runs(10L, 20L, c(10L, 200L, 30L))
  expect_identical(
    pix_read(q, as = "integer"),
    structure(
      array(rep(c(10L, 200L, 30L), each = 200L), c(10L, 20L, 3L)),
      bits = 8L
    )
  )
  # qoi.h would repeat the last pixel to fill a short stream; zupix refuses.
  for (k in 15:(length(q) - 1L)) {
    expect_error(pix_read(q[seq_len(k)]), class = "zupix_decode_error")
  }
})

test_that("QOI chunks must yield every pixel before the end marker", {
  head <- c(charToRaw("qoif"), be32(20L), be32(10L), as.raw(c(3L, 0L)))
  end <- as.raw(c(0, 0, 0, 0, 0, 0, 0, 1))
  rgb <- as.raw(c(0xfe, 10L, 200L, 30L))
  run <- function(n) as.raw(0xc0 + n - 1L)
  # 1 + 62 + 62 + 62 + 13 = 200 pixels.
  exact <- c(head, rgb, run(62L), run(62L), run(62L), run(13L), end)
  expect_identical(dim(pix_read(exact, as = "integer")), c(10L, 20L, 3L))
  short <- list(
    one_pixel_short = c(head, rgb, run(62L), run(62L), run(62L), run(12L), end),
    run_missing = c(head, rgb, run(62L), run(62L), run(62L), end),
    no_chunks = c(head, end),
    rgb_cut = c(head, rgb[1:2], end)
  )
  for (bad in short) {
    expect_error(pix_read(bad), class = "zupix_decode_error")
  }
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
  expect_error(pix_info(missing), class = "zupix_io_error")
  expect_error(pix_icc(missing), class = "zupix_io_error")
})

test_that("a directory is an I/O error, a non-scalar path an input error", {
  dir <- withr::local_tempdir()
  expect_error(pix_read(dir), class = "zupix_io_error")
  expect_error(pix_info(dir), class = "zupix_io_error")
  expect_error(pix_format(dir), class = "zupix_io_error")
  for (bad in list(c("a.png", "b.png"), NA_character_, 1L, list("a.png"))) {
    err <- expect_error(pix_read(bad), class = "zupix_input_error")
    expect_identical(err$arg, "x")
  }
  expect_error(pix_exif(NA_character_), class = "zupix_input_error")
})

test_that("connections are read whole, and must be binary and open", {
  p <- make_png(samples_for(2L, 2L, 3L, 255L), 2L, 2L)
  f <- withr::local_tempfile(fileext = ".png")
  writeBin(p, f)

  # An unopened connection is opened, read and closed by zupix.
  expect_identical(pix_info(file(f))$width, 2)
  expect_identical(
    pix_read(file(f), as = "integer"),
    pix_read(p, as = "integer")
  )

  text <- file(f, "r")
  withr::defer(close(text))
  err <- expect_error(pix_read(text), class = "zupix_input_error")
  expect_identical(err$arg, "x")

  closed <- file(f, "rb")
  close(closed)
  expect_error(pix_info(closed), class = "zupix_input_error")
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

test_that("every C status maps to its condition class", {
  failure <- function(status, limit = 0L, value = 0, cap = 0) {
    structure(
      list(
        status = status,
        detail = "a detail",
        limit = limit,
        value = value,
        cap = cap
      ),
      class = "zupix_failure"
    )
  }
  kinds <- c(
    "1" = "format",
    "2" = "decode",
    "3" = "unsupported",
    "4" = "limit",
    "5" = "memory",
    "6" = "input",
    "7" = "encode",
    "8" = "memory",
    "0" = "internal",
    "99" = "internal",
    "-1" = "internal"
  )
  for (status in names(kinds)) {
    f <- if (status == "4") {
      failure(4L, limit = 1L, value = 10, cap = 5)
    } else {
      failure(as.integer(status))
    }
    cls <- paste0("zupix_", kinds[[status]], "_error")
    err <- expect_error(
      zpx_raise_failure(f, "png", call = NULL),
      class = cls
    )
    expect_s3_class(
      err,
      c(cls, "zupix_error", "error", "condition"),
      exact = TRUE
    )
  }
  # A limit failure carries the limit's name, the value and the cap.
  for (k in 1:4) {
    err <- expect_error(
      zpx_raise_failure(failure(4L, k, 10, 5), "qoi", call = NULL),
      class = "zupix_limit_error"
    )
    expect_identical(err$limit, zpx_limit_names[[k]])
    expect_identical(c(err$value, err$cap), c(10, 5))
  }
  # A format mismatch names both formats.
  err <- expect_error(
    zpx_raise_failure(failure(1L, value = 1, cap = 2), "png", call = NULL),
    class = "zupix_format_error"
  )
  expect_identical(err$format, "png")
  # The others keep the decoder's detail and the format.
  err <- expect_error(
    zpx_raise_failure(failure(7L), "jpeg", call = NULL),
    class = "zupix_encode_error"
  )
  expect_identical(c(err$format, err$detail), c("jpeg", "a detail"))
})

test_that("condition messages", {
  failure <- function(status) {
    structure(
      list(
        status = status,
        detail = "a detail",
        limit = 0L,
        value = 0,
        cap = 0
      ),
      class = "zupix_failure"
    )
  }
  png <- make_png(samples_for(2L, 2L, 3L, 255L), 2L, 2L)
  jpg <- fixture("rgb.jpg")
  sof <- grepRaw(as.raw(c(0xff, 0xc0)), jpg)
  arithmetic <- jpg
  arithmetic[sof + 1L] <- as.raw(0xc9)
  short_qoi <- make_qoi_runs(2L, 2L, c(1L, 2L, 3L))[-19] # its run removed
  icc <- png_chunk(
    "iCCP",
    c(charToRaw("ICC"), as.raw(c(0, 0)), memCompress(raw(3000), "gzip"))
  )

  # zupix_input_error, from R and from C.
  expect_snapshot(error = TRUE, pix_read(1:3))
  expect_snapshot(error = TRUE, pix_read(png, as = "native", bits = 16L))
  expect_snapshot(error = TRUE, pix_read(png, as = "integer", channels = 1L))
  # zupix_format_error
  expect_snapshot(error = TRUE, pix_read(charToRaw("not an image")))
  expect_snapshot(error = TRUE, pix_read(png, format = "jpeg"))
  # zupix_unsupported_error
  expect_snapshot(error = TRUE, pix_read(arithmetic))
  # zupix_decode_error
  expect_snapshot(error = TRUE, pix_read(short_qoi))
  # zupix_limit_error, one per limit
  expect_snapshot(error = TRUE, pix_read(declared_png(1e6, 1)))
  expect_snapshot(error = TRUE, pix_read(declared_png(30000, 30000)))
  expect_snapshot(
    error = TRUE,
    pix_read(png, as = "double", limits = pix_limits(max_bytes = 100))
  )
  expect_snapshot(
    error = TRUE,
    pix_icc(
      make_png(matrix(0L), 1L, 0L, chunks_before = list(icc)),
      limits = pix_limits(max_metadata = 1000)
    )
  )
  # zupix_encode_error
  expect_snapshot(error = TRUE, pix_write_webp(matrix(0L, 1L, 16384L)))
  # zupix_io_error
  expect_snapshot(error = TRUE, pix_read("no/such/file.png"))
  # zupix_memory_error and zupix_internal_error, which R cannot provoke
  expect_snapshot(error = TRUE, zpx_raise_failure(failure(8L), "webp"))
  expect_snapshot(error = TRUE, zpx_raise_failure(failure(99L), NA))
})
