# JPEG and WebP decoding (design §2, §6.2, §6.6).

test_that("JPEG and WebP decode to the shapes of design §6.2", {
  cases <- list(
    "rgb.jpg" = 3L,
    "grey.jpg" = 1L,
    "lossy.webp" = 3L,
    "lossy-alpha.webp" = 4L,
    "lossless.webp" = 3L,
    "lossless-alpha.webp" = 4L
  )
  for (name in names(cases)) {
    f <- fixture(name)
    ch <- cases[[name]]
    int <- pix_read(f, as = "integer")
    expect_identical(attr(int, "bits"), 8L)
    expect_identical(dim(int), if (ch == 1L) c(12L, 16L) else c(12L, 16L, ch))
    expect_equal(as.vector(pix_read(f, as = "double")), as.vector(int) / 255)
    expect_s3_class(pix_read(f), "nativeRaster")
    expect_identical(attr(pix_read(f, as = "integer", bits = 16L), "bits"), 16L)
  }
})

test_that("JPEG codings Wuffs does not decode are unsupported, not corrupt", {
  jpg <- fixture("rgb.jpg")
  sof <- grepRaw(as.raw(c(0xff, 0xc0)), jpg)
  for (marker in c(0xc9, 0xc3, 0xc5)) {
    # arithmetic, lossless, hierarchical
    bad <- jpg
    bad[sof + 1L] <- as.raw(marker)
    expect_error(pix_read(bad), class = "zupix_unsupported_error")
  }
  twelve <- jpg
  twelve[sof + 4L] <- as.raw(12)
  expect_identical(pix_info(twelve)$bits, 12L)
  expect_error(pix_read(twelve), class = "zupix_unsupported_error")
})

test_that("truncated JPEG and WebP are decode errors", {
  for (name in c("rgb.jpg", "lossy.webp", "lossless.webp")) {
    f <- fixture(name)
    expect_error(
      pix_read(f[seq_len(length(f) - 10L)]),
      class = "zupix_decode_error"
    )
  }
})

test_that("an APNG decodes its default image, flagged as animated", {
  s <- samples_for(2L, 3L, 3L, 255L)
  apng <- make_png(s, 3L, 2L, chunks_before = apng_chunks(3L, 2L))
  expect_true(pix_info(apng)$animated)
  img <- pix_read(apng, as = "integer")
  expect_true(attr(img, "animated"))
  expect_identical(
    as.vector(img),
    as.vector(pix_read(make_png(s, 3L, 2L), as = "integer"))
  )
  expect_null(attr(pix_read(make_png(s, 3L, 2L)), "animated"))
})

test_that("an animated WebP decodes its first frame", {
  still <- fixture("lossy.webp")
  frame <- webp_bitstream(still)
  other <- webp_bitstream(fixture("lossless.webp"))
  anim <- webp_animated(16L, 12L, list(frame, other))
  i <- pix_info(anim)
  expect_true(i$animated)
  expect_identical(c(i$width, i$height), c(16, 12))

  img <- pix_read(anim, as = "integer")
  expect_true(attr(img, "animated"))
  attr(img, "animated") <- NULL
  expect_identical(img, pix_read(still, as = "integer"))
})

test_that("an animated WebP frame with alpha keeps it", {
  w <- fixture("lossy-alpha.webp")
  # The frame's chunks: everything after the still file's VP8X chunk.
  frame <- w[-(1:30)]
  anim <- webp_animated(16L, 12L, list(frame))
  img <- pix_read(anim, as = "integer")
  attr(img, "animated") <- NULL
  expect_identical(img, pix_read(w, as = "integer"))
})

test_that("an animated WebP whose first frame is not the canvas is unsupported", {
  frame <- webp_bitstream(fixture("lossy.webp"))
  anim <- webp_animated(20L, 12L, list(frame), fw = 16L, fh = 12L)
  expect_error(pix_read(anim), class = "zupix_unsupported_error")
})

test_that("jpeg::readJPEG() agrees within the recorded tolerance", {
  skip_if_not_installed("jpeg")
  # Grey is exact. Colour differs where chroma is upsampled, because the
  # jpeg package bundles IJG libjpeg 9e, whose upsampling differs from
  # libjpeg-turbo's (Wuffs matches libjpeg-turbo exactly: see the djpeg test
  # in test-conformance.R). On this 16 x 12 image edges dominate.
  tolerance <- c("grey.jpg" = 0, "rgb.jpg" = 9)
  for (name in names(tolerance)) {
    f <- test_path("fixtures", name)
    ours <- pix_read(f, as = "integer")
    theirs <- round(jpeg::readJPEG(f) * 255)
    expect_lte(max(abs(ours - theirs)), tolerance[[name]])
    expect_lt(mean(abs(ours - theirs)), 1.5)
  }
})

test_that("webp::read_webp() agrees exactly on lossless files", {
  skip_if_not_installed("webp")
  for (name in c("lossless.webp", "lossless-alpha.webp", "lossy-alpha.webp")) {
    f <- test_path("fixtures", name)
    ours <- pix_read(f, as = "integer")
    theirs <- webp::read_webp(f, numeric = FALSE)
    theirs <- aperm(array(as.integer(theirs), dim(theirs)), c(3L, 2L, 1L))
    ch <- dim(ours)[3]
    expect_identical(as.vector(ours), as.vector(theirs[,, seq_len(ch)]))
  }
})

test_that("an extended WebP with a VP8L bitstream decodes", {
  # Wuffs v0.4.0-alpha.12 fails on VP8L inside a VP8X container, with or
  # without the alpha flag the WebP container sets for transparency, though
  # the same VP8L chunk decodes on its own; zupix decodes such files from a
  # rebuilt simple-format copy.
  for (name in c("lossless.webp", "lossless-alpha.webp")) {
    w <- fixture(name)
    for (flags in c(0x00, 0x10, 0x08)) {
      if (flags == 0x10 && name == "lossless.webp") {
        next
      }
      ext <- webp_extended(flags, 16L, 12L, list(webp_bitstream(w)))
      expect_identical(
        pix_read(ext, as = "integer"),
        pix_read(w, as = "integer")
      )
    }
  }
  ext <- webp_extended(
    0x10,
    16L,
    12L,
    list(webp_bitstream(fixture("lossless-alpha.webp")))
  )
  expect_true(pix_info(ext)$alpha)
})
