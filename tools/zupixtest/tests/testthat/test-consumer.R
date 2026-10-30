# Everything here reaches zupix only through the C table zupix-r.h
# resolves, and checks the answers against zupix's own R functions.
# Enum values are zupix.h's.
PNG <- 1L
JPEG <- 2L
WEBP <- 3L
QOI <- 4L
RGBA8 <- 1L
RGB8 <- 2L
Y8 <- 3L
RGBA16 <- 4L
Y16 <- 5L
OK <- 0L
ERR_ARGUMENT <- 6L
ERR_SINK <- 8L

rgba_png <- function() {
  img <- array(as.integer((1:(5 * 7 * 4) * 37L) %% 256L), c(5L, 7L, 4L))
  attr(img, "bits") <- 8L
  zupix::pix_write_png(img)
}
# Row-major interleaved bytes of an integer array pix_read() returned.
interleave <- function(a) {
  d <- dim(a)
  if (length(d) == 2L) {
    d <- c(d, 1L)
  }
  v <- aperm(array(a, d), c(3L, 2L, 1L))
  as.vector(v)
}

test_that("the table resolves at ABI version 1", {
  t <- zt_table()
  expect_identical(t[[1]], 1L)
  expect_gt(t[[2]], 0L)
})

test_that("another ABI version gets NULL", {
  expect_true(zt_future_abi())
})

test_that("probe() agrees with pix_info()", {
  p <- rgba_png()
  pr <- zt_probe(p)
  info <- zupix::pix_info(p)
  expect_identical(pr[["status"]], OK)
  expect_identical(pr[["format"]], PNG)
  expect_identical(c(pr[["width"]], pr[["height"]]), c(7L, 5L))
  expect_identical(pr[["channels"]], 4L)
  expect_identical(pr[["status"]], zt_probe(p)[["status"]])
  expect_identical(zt_probe(charToRaw("junk"))[["status"]], 1L)
  expect_identical(info$width, 7)
})

test_that("decode() into RGBA8 matches pix_read()'s pixels, through a stride", {
  p <- rgba_png()
  got <- zt_decode(p, RGBA8)
  want <- interleave(zupix::pix_read(p, as = "integer"))
  expect_identical(as.integer(got), want)
})

test_that("decode() adds channels and depth but never removes them", {
  grey <- matrix(as.integer((1:12 * 21L) %% 256L), 3L)
  attr(grey, "bits") <- 8L
  g <- zupix::pix_write_png(grey)
  expect_identical(as.integer(zt_decode(g, Y8)), interleave(unclass(grey)[,]))
  rgb <- zt_decode(g, RGB8)
  expect_identical(
    as.integer(rgb[seq(1, length(rgb), 3)]),
    interleave(unclass(grey)[,])
  )
  y16 <- zt_decode(g, Y16)
  expect_length(y16, 2L * 12L)

  wide <- array(as.integer((1:(2 * 3 * 4) * 2711L) %% 65536L), c(2L, 3L, 4L))
  attr(wide, "bits") <- 16L
  w <- zupix::pix_write_png(wide)
  r16 <- zt_decode(w, RGBA16)
  v <- readBin(
    r16,
    "integer",
    n = length(r16) / 2L,
    size = 2L,
    signed = FALSE,
    endian = .Platform$endian
  )
  expect_identical(v, interleave(unclass(wide)))

  # A colour image to grey, or alpha dropped: refused.
  expect_identical(zt_decode(rgba_png(), Y8), ERR_ARGUMENT)
  expect_identical(zt_decode(rgba_png(), RGB8), ERR_ARGUMENT)
})

test_that("metadata() returns what pix_icc() and pix_exif() do", {
  img <- array(1L, c(2L, 2L, 3L))
  icc <- as.raw(rep(0:255, 4))
  exif <- as.raw(c(0x49, 0x49, 0x2a, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  for (f in list(
    zupix::pix_write_png(img, icc = icc, exif = exif),
    zupix::pix_write_jpeg(img, icc = icc, exif = exif)
  )) {
    expect_identical(zt_metadata(f, "icc"), icc)
    expect_identical(zt_metadata(f, "exif"), exif)
  }
  expect_identical(zt_metadata(zupix::pix_write_png(img), "icc"), raw())
})

test_that("encode() writes every format, and they decode back", {
  img <- array(as.integer((1:(6 * 4 * 4) * 13L) %% 256L), c(6L, 4L, 4L))
  attr(img, "bits") <- 8L
  rgba <- as.raw(interleave(unclass(img)))
  for (fmt in c(PNG, WEBP, QOI)) {
    out <- zt_encode(rgba, fmt, RGBA8, 4L, 6L)
    expect_type(out, "raw")
    expect_identical(
      zupix::pix_format(out),
      c("png", "jpeg", "webp", "qoi")[[fmt]]
    )
  }
  expect_identical(
    zupix::pix_read(zt_encode(rgba, PNG, RGBA8, 4L, 6L), as = "integer"),
    img
  )
  expect_identical(
    zupix::pix_read(zt_encode(rgba, QOI, RGBA8, 4L, 6L), as = "integer"),
    img
  )
  rgb <- as.raw(interleave(unclass(img)[,, 1:3]))
  j <- zt_encode(rgb, JPEG, RGB8, 4L, 6L)
  expect_identical(zupix::pix_format(j), "jpeg")
  # JPEG refuses transparency, accepts an opaque alpha.
  expect_identical(zt_encode(rgba, JPEG, RGBA8, 4L, 6L), ERR_ARGUMENT)
  opaque <- unclass(img)
  opaque[,, 4] <- 255L
  expect_type(zt_encode(as.raw(interleave(opaque)), JPEG, RGBA8, 4L, 6L), "raw")
})

test_that("a failing sink is ZPX_ERR_SINK", {
  rgb <- as.raw(rep(1:255, 3)[1:(3 * 3 * 3)])
  for (fmt in c(PNG, JPEG, WEBP, QOI)) {
    expect_identical(zt_encode_failing_sink(rgb, fmt, RGB8, 3L, 3L), ERR_SINK)
  }
})

test_that("status_string() names every status", {
  for (s in 0:8) {
    expect_true(nzchar(zt_status_string(s)))
  }
})
