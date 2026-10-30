# Design §4.2 and §6.2: lossless encoders, round trips and input rules.

test_that("PNG round trips are identical at 8 and 16 bits, every channel count", {
  for (bits in c(8L, 16L)) {
    for (ch in 1:4) {
      for (size in list(c(1L, 1L), c(7L, 5L), c(16L, 33L))) {
        img <- random_image(size[[1]], size[[2]], ch, bits, seed = ch + bits)
        back <- pix_read(pix_write_png(img), as = "integer")
        expect_identical(back, img)
      }
    }
  }
})

test_that("every compression level round-trips and 9 is no larger than 0", {
  img <- random_image(20L, 30L, 3L, 8L)
  # A smooth image, so compression has something to find.
  smooth <- array(as.integer(outer(1:20, 1:30, "+") %% 256L), c(20L, 30L, 3L))
  attr(smooth, "bits") <- 8L
  sizes <- integer()
  for (level in 0:9) {
    expect_identical(
      pix_read(pix_write_png(img, compression = level), as = "integer"),
      img
    )
    sizes[[level + 1L]] <- length(pix_write_png(smooth, compression = level))
  }
  expect_lte(sizes[[10]], sizes[[1]])
})

test_that("png::readPNG() reads every PNG zupix writes, with the same pixels", {
  skip_if_not_installed("png")
  for (bits in c(8L, 16L)) {
    for (ch in 1:4) {
      img <- random_image(6L, 9L, ch, bits, seed = 10L + ch)
      expect_identical(
        png::readPNG(pix_write_png(img)),
        pix_read(pix_write_png(img), as = "double")
      )
    }
  }
})

test_that("QOI round trips are identical, and grey widens to RGB", {
  for (ch in 3:4) {
    img <- random_image(9L, 13L, ch, 8L, seed = ch)
    expect_identical(pix_read(pix_write_qoi(img), as = "integer"), img)
  }
  grey <- random_image(4L, 5L, 1L, 8L)
  rgb <- pix_read(pix_write_qoi(grey), as = "integer")
  expect_identical(dim(rgb), c(4L, 5L, 3L))
  for (k in 1:3) {
    expect_identical(rgb[,, k], unclass(grey)[,])
  }
  ga <- random_image(4L, 5L, 2L, 8L)
  rgba <- pix_read(pix_write_qoi(ga), as = "integer")
  expect_identical(rgba[,, 4], unclass(ga)[,, 2])
})

test_that("QOI's colourspace byte is written, and 16-bit input is refused", {
  img <- random_image(2L, 2L, 3L, 8L)
  expect_false(pix_info(pix_write_qoi(img))$qoi_linear)
  expect_true(pix_info(pix_write_qoi(img, colourspace = "linear"))$qoi_linear)
  expect_error(
    pix_write_qoi(random_image(2L, 2L, 3L, 16L)),
    class = "zupix_input_error"
  )
})

test_that("qoi::readQOI() reads every QOI zupix writes", {
  skip_if_not_installed("qoi")
  f <- withr::local_tempfile(fileext = ".qoi")
  for (ch in 3:4) {
    img <- random_image(5L, 6L, ch, 8L, seed = ch)
    pix_write_qoi(img, f)
    expect_identical(as.vector(qoi::readQOI(f)), as.vector(img))
  }
})

test_that("ICC and EXIF bytes survive a PNG round trip; sRGB is written", {
  img <- random_image(3L, 4L, 3L, 8L)
  icc <- as.raw(rep(0:255, 7))
  exif <- exif_block(6L)
  p <- pix_write_png(img, icc = icc, exif = exif)
  expect_identical(pix_icc(p), icc)
  expect_identical(pix_exif(p), exif)
  expect_identical(pix_info(p)$orientation, 6L)

  s <- pix_write_png(img, srgb = 1L)
  expect_identical(pix_info(s)$srgb, 1L)
  expect_error(
    pix_write_png(img, icc = icc, srgb = 0L),
    class = "zupix_input_error"
  )
})

test_that("doubles are clamped to [0, 1] and rounded to `bits`", {
  x <- matrix(c(-0.5, 0, 0.5, 1, 1.5, 0.2), nrow = 2L)
  expect_identical(
    as.vector(pix_read(pix_write_png(x), as = "integer")),
    as.integer(round(pmin(pmax(as.vector(x), 0), 1) * 255))
  )
  expect_identical(
    as.vector(pix_read(pix_write_png(x, bits = 16L), as = "integer")),
    as.integer(round(pmin(pmax(as.vector(x), 0), 1) * 65535))
  )
  # What pix_read() gives as doubles writes back exactly.
  d <- pix_read(pix_write_png(random_image(4L, 4L, 4L, 8L)), as = "double")
  expect_identical(pix_read(pix_write_png(d), as = "double"), d)
})

test_that("integers without `bits` are 8-bit up to 255, else an error naming bits", {
  m <- matrix(c(0L, 100L, 255L, 7L), 2L)
  expect_identical(attr(pix_read(pix_write_png(m), as = "integer"), "bits"), 8L)
  big <- matrix(c(0L, 300L, 255L, 7L), 2L)
  err <- expect_error(pix_write_png(big), class = "zupix_input_error")
  expect_identical(err$arg, "bits")
  attr(big, "bits") <- 16L
  expect_identical(
    as.vector(pix_read(pix_write_png(big), as = "integer")),
    as.vector(big)
  )
})

test_that("forced bits convert between 8 and 16 bits", {
  img <- random_image(3L, 3L, 3L, 8L)
  up <- pix_read(pix_write_png(img, bits = 16L), as = "integer")
  expect_identical(as.vector(up), as.vector(img) * 257L)
  down <- pix_read(pix_write_png(up, bits = 8L), as = "integer")
  expect_identical(down, img)
})

test_that("a nativeRaster writes as RGBA", {
  f <- system.file("extdata", "gradient.png", package = "zupix")
  n <- pix_read(f)
  expect_identical(pix_read(pix_write_png(n)), n)
  expect_identical(pix_read(pix_write_qoi(n)), n)
  expect_error(pix_write_png(n, bits = 16L), class = "zupix_input_error")
})

test_that("bad images and arguments are input errors", {
  img <- random_image(2L, 2L, 3L, 8L)
  expect_error(pix_write_png(1:4), class = "zupix_input_error")
  expect_error(
    pix_write_png(array(0L, c(2L, 2L, 5L))),
    class = "zupix_input_error"
  )
  expect_error(
    pix_write_png(matrix(c(1L, NA), 1L)),
    class = "zupix_input_error"
  )
  bad <- matrix(c(-1L, 3L), 1L)
  expect_error(pix_write_png(bad), class = "zupix_input_error")
  frac <- matrix(c(1, 2.5), 1L)
  attr(frac, "bits") <- 8L
  expect_error(pix_write_png(frac), class = "zupix_input_error")
  expect_error(
    pix_write_png(img, compression = 10L),
    class = "zupix_input_error"
  )
  expect_error(pix_write_png(img, icc = "profile"), class = "zupix_input_error")
  expect_error(pix_write_png(img, srgb = 4L), class = "zupix_input_error")
  expect_error(
    pix_write_qoi(img, colourspace = "p3"),
    class = "zupix_input_error"
  )
  expect_error(pix_write_png(img, file = 1), class = "zupix_input_error")
})

test_that("pix_write() picks the writer from the extension or `format`", {
  dir <- withr::local_tempdir()
  img <- random_image(3L, 4L, 3L, 8L)
  for (ext in c("png", "qoi", "PNG")) {
    f <- file.path(dir, paste0("a.", ext))
    expect_identical(pix_write(img, f), f)
    expect_identical(pix_format(f), tolower(ext))
    expect_identical(pix_read(f, as = "integer"), img)
  }
  f <- file.path(dir, "noext")
  pix_write(img, f, format = "qoi")
  expect_identical(pix_format(f), "qoi")
  expect_error(
    pix_write(img, file.path(dir, "a.tiff")),
    class = "zupix_input_error"
  )
  expect_identical(pix_write(img, NULL, format = "png"), pix_write_png(img))
})

test_that("an unwritable path is an I/O error", {
  img <- random_image(2L, 2L, 3L, 8L)
  bad <- file.path(withr::local_tempdir(), "missing-dir", "a.png")
  expect_error(pix_write(img, bad), class = "zupix_io_error")
})

test_that("encoding is deterministic", {
  img <- random_image(8L, 8L, 4L, 16L)
  expect_identical(pix_write_png(img), pix_write_png(img))
  expect_identical(
    pix_write_qoi(random_image(8L, 8L, 4L, 8L)),
    pix_write_qoi(random_image(8L, 8L, 4L, 8L))
  )
})

test_that("lossless round trips hold on many random images", {
  # Design §12 asks for 10^4 per format and depth; that runs where
  # ZUPIX_ROUNDTRIPS=10000 (hardening.yaml). The default keeps CRAN quick.
  n <- as.integer(Sys.getenv("ZUPIX_ROUNDTRIPS", "25"))
  withr::local_seed(12L)
  for (i in seq_len(n)) {
    h <- sample.int(24L, 1L)
    w <- sample.int(24L, 1L)
    ch <- sample.int(4L, 1L)
    for (bits in c(8L, 16L)) {
      img <- random_image(h, w, ch, bits, seed = i * 2L + bits)
      expect_identical(pix_read(pix_write_png(img), as = "integer"), img)
    }
    rgb <- random_image(h, w, sample(3:4, 1L), 8L, seed = i)
    expect_identical(pix_read(pix_write_qoi(rgb), as = "integer"), rgb)
    expect_identical(
      pix_read(pix_write_webp(rgb, lossless = TRUE), as = "integer"),
      rgb
    )
  }
})
