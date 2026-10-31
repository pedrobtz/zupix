# Design §9: the conformance corpora, and the differential oracles on them.
# PngSuite and libjpeg-turbo's test images are committed (their licences
# allow it: tests/testthat/corpus/, tools/make-corpus.sh). libwebp-test-data
# and the QOI test images are not redistributable; set ZUPIX_CORPUS to a
# directory holding them (as hardening.yaml does) to run those tests.

test_that("every valid PngSuite file decodes as png::readPNG() does", {
  skip_if_not_installed("png")
  files <- pngsuite()
  valid <- files[!startsWith(basename(files), "x")]
  expect_gt(length(valid), 150L)
  for (f in valid) {
    ours <- pix_read(f, as = "double")
    theirs <- suppressWarnings(png::readPNG(f))
    attributes(theirs) <- attributes(theirs)["dim"]
    expect_identical(ours, theirs, info = basename(f))
  }
})

test_that("every valid PngSuite file decodes in all three shapes", {
  skip_if_not_installed("png")
  # One expectation for the whole corpus, naming the files that differ:
  # several per file would cost more time than the decoding.
  bad <- character()
  for (f in pngsuite()[!startsWith(basename(pngsuite()), "x")]) {
    i <- pix_info(f)
    bits <- if (i$bits == 16L) 16L else 8L
    native <- pix_read(f)
    int <- pix_read(f, as = "integer")
    dbl <- pix_read(f, as = "double")
    theirs <- suppressWarnings(png::readPNG(f))
    attributes(theirs) <- attributes(theirs)["dim"]
    ok <- identical(dim(native)[1:2], as.integer(c(i$height, i$width))) &&
      identical(attr(int, "bits"), bits) &&
      identical(dim(dbl), dim(int)) &&
      # The integer and double shapes hold the same samples, scaled, and
      # the doubles are png::readPNG()'s exactly.
      identical(as.vector(dbl), as.vector(int) / (2^bits - 1)) &&
      identical(dbl, theirs)
    if (!ok) {
      bad <- c(bad, basename(f))
    }
  }
  expect_identical(bad, character())
})

test_that("every corrupt PngSuite file fails with the class its name predicts", {
  # x?? files: xs* and xcr/xlf have a damaged signature; the rest a damaged
  # header, checksum or missing data.
  for (f in pngsuite()[startsWith(basename(pngsuite()), "x")]) {
    n <- basename(f)
    cls <- if (grepl("^x(s|cr|lf)", n)) {
      "zupix_format_error"
    } else {
      "zupix_decode_error"
    }
    expect_error(pix_read(f), class = cls, info = n)
  }
})

test_that("libjpeg-turbo's test images decode or are named unsupported", {
  d <- test_path("corpus", "libjpeg-turbo")
  for (n in c("testorig.jpg", "testimgint.jpg")) {
    img <- pix_read(file.path(d, n), as = "integer")
    expect_identical(dim(img), c(149L, 227L, 3L))
  }
  # Arithmetic coding and 12-bit precision are outside v0.1.0 (design §2).
  expect_error(
    pix_read(file.path(d, "testimgari.jpg")),
    class = "zupix_unsupported_error"
  )
  m12 <- file.path(d, "monkey12.jpg")
  expect_identical(pix_info(m12)$bits, 12L)
  expect_error(pix_read(m12), class = "zupix_unsupported_error")
  # Its embedded sRGB2014.icc reassembles to the profile's own length.
  icc <- pix_icc(m12)
  expect_length(icc, 3024L)
  expect_identical(rawToChar(icc[37:40]), "acsp")
})

test_that("Wuffs decodes JPEG exactly as libjpeg-turbo's djpeg does", {
  djpeg <- Sys.which("djpeg")
  skip_if(!nzchar(djpeg), "djpeg (libjpeg-turbo) is not installed")
  files <- c(
    file.path(
      test_path("corpus", "libjpeg-turbo"),
      c("testorig.jpg", "testimgint.jpg")
    ),
    test_path("fixtures", c("rgb.jpg", "grey.jpg"))
  )
  prog <- withr::local_tempfile(fileext = ".jpg")
  pix_write_jpeg(smooth_rgb(), prog, progressive = TRUE)
  for (f in c(files, prog)) {
    out <- withr::local_tempfile(fileext = ".pnm")
    system2(djpeg, c("-pnm", "-outfile", out, f))
    ours <- pix_read(f, as = "integer")
    attr(ours, "bits") <- NULL
    expect_identical(ours, read_pnm(out), info = basename(f))
  }
})

test_that("every libwebp-test-data file decodes; lossless and alpha exactly", {
  skip_if_not_installed("webp")
  d <- corpus_dir("libwebp-test-data")
  files <- list.files(d, "[.]webp$", full.names = TRUE)
  expect_gt(length(files), 100L)
  # Wuffs v0.4.0-alpha.12's VP8 (lossy) decoder differs from libwebp on
  # these files, in the colour channels only, though VP8 is specified
  # bit-exactly (RFC 6386); measured 2026-10-30, worst difference in
  # levels. Recorded so a Wuffs update that fixes them shows up here.
  # Reported as https://github.com/google/wuffs/issues/211.
  known <- c(
    bryce = 11,
    lossy_alpha1 = 12,
    lossy_alpha2 = 32,
    lossy_alpha3 = 8,
    lossy_q0_f100 = 2,
    segment01 = 2,
    segment02 = 30,
    segment03 = 21
  )
  for (f in files) {
    n <- sub("[.]webp$", "", basename(f))
    ours <- pix_read(f, as = "integer")
    theirs <- webp::read_webp(f, numeric = FALSE)
    theirs <- aperm(array(as.integer(theirs), dim(theirs)), c(3L, 2L, 1L))
    ch <- dim(ours)[3]
    diff <- abs(ours - theirs[,, seq_len(ch), drop = FALSE])
    if (ch == 4L) {
      expect_equal(max(diff[,, 4, drop = FALSE]), 0, info = n)
    }
    if (n %in% names(known)) {
      expect_lte(max(diff), known[[n]], label = n)
      expect_gt(max(diff), 0, label = paste(n, "(fixed upstream?)"))
    } else {
      expect_equal(max(diff), 0, info = n)
    }
  }
})

test_that("every QOI test image decodes to its PNG's pixels and as qoi.h does", {
  d <- file.path(corpus_dir("qoi_test_images"))
  for (q in list.files(d, "[.]qoi$", full.names = TRUE)) {
    n <- basename(q)
    ours <- pix_read(q, as = "integer")
    png <- pix_read(sub("[.]qoi$", ".png", q), as = "integer")
    ch <- dim(png)[3]
    expect_identical(
      as.vector(ours[,, seq_len(ch), drop = FALSE]),
      as.vector(png),
      info = n
    )
    if (requireNamespace("qoi", quietly = TRUE)) {
      # Every channel, alpha included, as the reference decoder gives them.
      # edgecase.qoi is the one Wuffs got wrong (a QOI_OP_RUN's pixel never
      # entered its colour index, https://github.com/google/wuffs/issues/209),
      # which is why QOI decodes through qoi.h.
      ref <- qoi::readQOI(q)
      expect_identical(as.vector(ours), as.vector(ref), info = n)
    }
  }
})

test_that("QOI decodes as the qoi package's qoi.h does, offline", {
  skip_if_not_installed("qoi")
  f <- withr::local_tempfile(fileext = ".qoi")
  # Images that use every chunk type: runs (flat areas), the colour index
  # (a run's pixel seen again, the case Wuffs got wrong), small and luma
  # deltas (gradients) and full RGB and RGBA chunks (noise, alpha).
  withr::local_seed(48L)
  flat <- array(c(rep(10L, 60), rep(200L, 60), rep(30L, 60)), c(6L, 10L, 3L))
  stripes <- flat
  stripes[, c(2L, 5L, 8L), ] <- 90L
  noise <- array(sample(0:255, 6L * 10L * 4L, TRUE), c(6L, 10L, 4L))
  noise[1:3, 1:5, ] <- 255L
  smooth <- smooth_rgb(12L, 16L)
  inputs <- list(
    runs = make_qoi_runs(10L, 20L, c(1L, 2L, 3L)),
    rgba_ops = make_qoi(noise),
    fixture = fixture("smooth.qoi")
  )
  for (img in list(flat, stripes, noise, unclass(smooth))) {
    inputs[[length(inputs) + 1L]] <- qoi::writeQOI(img)
  }
  for (i in seq_along(inputs)) {
    writeBin(inputs[[i]], f)
    ours <- pix_read(inputs[[i]], as = "integer")
    ref <- qoi::readQOI(f)
    expect_identical(as.vector(ours), as.vector(ref), info = i)
    expect_identical(dim(ours), dim(ref), info = i)
  }
})
