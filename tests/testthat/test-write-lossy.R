# Design §4.2, §9: lossy encoders above recorded PSNR floors, lossless WebP
# exact, and metadata embedded by every encoder.

test_that("JPEG stays above its recorded PSNR floor at each quality", {
  img <- smooth_rgb()
  # Measured 41.1, 44.2, 47.4 and 50.7 dB on 2026-10-30; floors 3 dB lower.
  floors <- c("50" = 38, "75" = 41, "90" = 44, "100" = 47)
  for (q in names(floors)) {
    back <- pix_read(
      pix_write_jpeg(img, quality = as.integer(q)),
      as = "integer"
    )
    expect_gte(psnr(back, img), floors[[q]])
  }
})

test_that("lossy WebP stays above its recorded PSNR floor at each quality", {
  img <- smooth_rgb()
  # Measured 37.1, 38.1, 40.2 and 46.7 dB on 2026-10-30; floors 3 dB lower.
  floors <- c("25" = 34, "50" = 35, "75" = 37, "95" = 43)
  for (q in names(floors)) {
    back <- pix_read(
      pix_write_webp(img, quality = as.numeric(q)),
      as = "integer"
    )
    expect_gte(psnr(back, img), floors[[q]])
  }
})

test_that("lossless WebP round trips are identical, RGB and RGBA", {
  for (ch in 3:4) {
    img <- random_image(9L, 13L, ch, 8L, seed = ch)
    expect_identical(
      pix_read(pix_write_webp(img, lossless = TRUE), as = "integer"),
      img
    )
  }
  grey <- random_image(4L, 5L, 1L, 8L)
  rgb <- pix_read(pix_write_webp(grey, lossless = TRUE), as = "integer")
  for (k in 1:3) {
    expect_identical(rgb[,, k], unclass(grey)[,])
  }
})

test_that("lossy WebP keeps alpha exactly", {
  img <- random_image(8L, 8L, 4L, 8L)
  for (q in c(0, 50, 90)) {
    back <- pix_read(pix_write_webp(img, quality = q), as = "integer")
    expect_identical(dim(back), c(8L, 8L, 4L))
    # libwebp compresses the alpha plane losslessly by default.
    expect_identical(back[,, 4], unclass(img)[,, 4])
  }
  expect_true(pix_info(pix_write_webp(img))$alpha)
})

test_that("JPEG writes grey, RGB, progressive and every subsampling", {
  img <- smooth_rgb(32L, 48L)
  for (ss in c("4:4:4", "4:2:2", "4:2:0")) {
    j <- pix_write_jpeg(img, subsampling = ss)
    expect_identical(dim(pix_read(j, as = "integer")), c(32L, 48L, 3L))
  }
  expect_false(pix_info(pix_write_jpeg(img))$interlaced)
  p <- pix_write_jpeg(img, progressive = TRUE)
  expect_true(pix_info(p)$interlaced)
  expect_gte(psnr(pix_read(p, as = "integer"), img), 40)

  grey <- img[,, 1]
  attr(grey, "bits") <- 8L
  g <- pix_write_jpeg(grey)
  expect_identical(pix_info(g)$colour_type, "grey")
  expect_identical(dim(pix_read(g, as = "integer")), c(32L, 48L))
})

test_that("JPEG drops an opaque alpha channel and refuses transparency", {
  img <- random_image(4L, 4L, 4L, 8L)
  img[,, 4] <- 255L
  expect_identical(pix_info(pix_write_jpeg(img))$colour_type, "ycbcr")
  n <- pix_read(system.file("extdata", "gradient.png", package = "zupix"))
  expect_identical(dim(pix_read(pix_write_jpeg(n))), dim(n))
  img[1, 1, 4] <- 0L
  expect_error(pix_write_jpeg(img), class = "zupix_input_error")
})

test_that("16-bit input is rounded to 8 bits for JPEG and WebP", {
  img <- random_image(4L, 4L, 3L, 8L)
  wide <- img
  wide[] <- unclass(img) * 257L
  attr(wide, "bits") <- 16L
  expect_identical(
    pix_write_webp(wide, lossless = TRUE),
    pix_write_webp(img, lossless = TRUE)
  )
  expect_identical(pix_write_jpeg(wide), pix_write_jpeg(img))
})

test_that("ICC and EXIF bytes survive every encoder unchanged", {
  icc <- as.raw(rep(0:255, 3))
  exif <- exif_block(6L)
  rgb <- smooth_rgb(16L, 16L)
  rgba <- random_image(16L, 16L, 4L, 8L)
  encoded <- list(
    png = pix_write_png(rgb, icc = icc, exif = exif),
    jpeg = pix_write_jpeg(rgb, icc = icc, exif = exif),
    jpeg_prog = pix_write_jpeg(rgb, icc = icc, exif = exif, progressive = TRUE),
    webp = pix_write_webp(rgb, icc = icc, exif = exif),
    webp_alpha = pix_write_webp(rgba, icc = icc, exif = exif),
    webp_lossless = pix_write_webp(
      rgba,
      lossless = TRUE,
      icc = icc,
      exif = exif
    )
  )
  for (name in names(encoded)) {
    e <- encoded[[name]]
    expect_identical(pix_icc(e), icc, info = name)
    expect_identical(pix_exif(e), exif, info = name)
    expect_identical(pix_info(e)$orientation, 6L, info = name)
    expect_no_error(pix_read(e))
  }
  # An ICC profile larger than one APP2 segment is split and rejoined.
  big <- as.raw(rep(0:255, 400))
  expect_identical(pix_icc(pix_write_jpeg(rgb, icc = big)), big)
  # Metadata changes nothing about the pixels.
  expect_identical(
    pix_read(encoded$webp_lossless, as = "integer"),
    pix_read(pix_write_webp(rgba, lossless = TRUE), as = "integer")
  )
})

test_that("jpeg::readJPEG() reads every JPEG zupix writes", {
  skip_if_not_installed("jpeg")
  img <- smooth_rgb(24L, 32L)
  for (args in list(
    list(),
    list(progressive = TRUE),
    list(subsampling = "4:4:4"),
    list(quality = 30L)
  )) {
    j <- do.call(pix_write_jpeg, c(list(img), args))
    theirs <- round(jpeg::readJPEG(j) * 255)
    expect_identical(dim(theirs), c(24L, 32L, 3L))
    expect_gte(psnr(theirs, img), 30)
  }
})

test_that("webp::read_webp() reads every WebP zupix writes", {
  skip_if_not_installed("webp")
  rgba <- random_image(8L, 8L, 4L, 8L)
  f <- withr::local_tempfile(fileext = ".webp")
  for (args in list(
    list(lossless = TRUE),
    list(quality = 80),
    list(lossless = TRUE, icc = as.raw(1:10), exif = exif_block(2L))
  )) {
    do.call(pix_write_webp, c(list(rgba, f), args))
    theirs <- webp::read_webp(f, numeric = FALSE)
    expect_identical(dim(theirs), c(4L, 8L, 8L))
    if (isTRUE(args$lossless)) {
      theirs <- aperm(array(as.integer(theirs), dim(theirs)), c(3L, 2L, 1L))
      expect_identical(as.vector(theirs), as.vector(rgba))
    }
  }
})

test_that("format limits are encode errors", {
  wide <- matrix(0L, 1L, 16384L)
  expect_error(pix_write_webp(wide), class = "zupix_encode_error")
  expect_error(
    pix_write_jpeg(matrix(0L, 1L, 65536L)),
    class = "zupix_encode_error"
  )
  expect_error(
    pix_write_jpeg(smooth_rgb(4L, 4L), exif = raw(70000)),
    class = "zupix_encode_error"
  )
})

test_that("pix_write() dispatches .jpg, .jpeg and .webp", {
  dir <- withr::local_tempdir()
  img <- smooth_rgb(8L, 8L)
  for (ext in c("jpg", "jpeg", "webp")) {
    f <- file.path(dir, paste0("a.", ext))
    pix_write(img, f)
    expect_identical(pix_format(f), if (ext == "webp") "webp" else "jpeg")
  }
  f <- file.path(dir, "b.webp")
  pix_write(img, f, lossless = TRUE)
  back <- pix_read(f, as = "integer")
  expect_identical(back, img)
})

test_that("lossy writers reject bad arguments", {
  img <- smooth_rgb(4L, 4L)
  expect_error(pix_write_jpeg(img, quality = 0L), class = "zupix_input_error")
  expect_error(
    pix_write_jpeg(img, subsampling = "4:1:1"),
    class = "zupix_input_error"
  )
  expect_error(
    pix_write_jpeg(img, progressive = NA),
    class = "zupix_input_error"
  )
  expect_error(pix_write_webp(img, quality = 101), class = "zupix_input_error")
  expect_error(pix_write_webp(img, method = 7L), class = "zupix_input_error")
  expect_error(
    pix_write_webp(img, lossless = "yes"),
    class = "zupix_input_error"
  )
})
