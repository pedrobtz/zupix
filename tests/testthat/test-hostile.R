# Design §6.5, §9: hostile input. A file per limit, and every corpus file
# truncated: each must fail with a zupix condition or succeed, never crash
# and never fail any other way. By default each file is cut at a sample of
# offsets, to stay inside CRAN's time budget; ZUPIX_HOSTILE=full cuts every
# file at each of its first 4,096 offsets and 64 random later ones, as
# design §9 asks (hardening.yaml sets it).

test_that("a JPEG declaring 65,535 x 65,535 fails on the pixel limit", {
  jpg <- fixture("rgb.jpg")
  sof <- grepRaw(as.raw(c(0xff, 0xc0)), jpg)
  jpg[sof + 5:8] <- as.raw(c(0xff, 0xff, 0xff, 0xff))
  err <- expect_error(pix_read(jpg), class = "zupix_limit_error")
  expect_identical(err$limit, "max_pixels")
  expect_identical(pix_info(jpg)$width, 65535)
})

test_that("a maximal VP8X canvas fails on the side limit", {
  w <- webp_extended(0, 2^24, 2^24, list(webp_bitstream(fixture("lossy.webp"))))
  err <- expect_error(pix_read(w), class = "zupix_limit_error")
  expect_identical(err$limit, "max_side")
  expect_identical(err$value, 2^24)
})

test_that("a QOI header declaring 4 billion pixels fails on the side limit", {
  q <- make_qoi(array(1L, c(1L, 1L, 3L)))
  q[5:12] <- c(be32(70000), be32(70000))
  expect_error(pix_read(q), class = "zupix_limit_error")
})

test_that("every corpus file, truncated, fails cleanly or decodes", {
  withr::local_seed(20261030L)
  full <- identical(Sys.getenv("ZUPIX_HOSTILE"), "full")
  for (f in hostile_files()) {
    bytes <- readBin(f, "raw", file.size(f))
    bad <- character()
    for (k in cut_points(length(bytes), full)) {
      cut <- bytes[seq_len(k)]
      where <- paste(basename(f), k)
      bad <- c(
        bad,
        not_clean(pix_read, cut, where),
        not_clean(pix_info, cut, where),
        not_clean(pix_icc, cut, where)
      )
    }
    expect_identical(bad, character(), info = basename(f))
  }
})

test_that("every corpus file, with one byte flipped, fails cleanly or decodes", {
  withr::local_seed(20261031L)
  full <- identical(Sys.getenv("ZUPIX_HOSTILE"), "full")
  for (f in hostile_files()) {
    bytes <- readBin(f, "raw", file.size(f))
    bad <- character()
    for (k in sample(
      length(bytes),
      min(length(bytes), if (full) 256L else 2L)
    )) {
      flipped <- bytes
      flipped[k] <- xor(flipped[k], as.raw(sample(1:255, 1L)))
      where <- paste(basename(f), k)
      bad <- c(
        bad,
        not_clean(function(b) pix_read(b, as = "double"), flipped, where),
        not_clean(pix_info, flipped, where),
        not_clean(pix_exif, flipped, where)
      )
    }
    expect_identical(bad, character(), info = basename(f))
  }
})
