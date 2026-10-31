# Design §6.4: what the scanners read, field by field, and what they refuse.

test_that("pix_info() reads the PNG colour chunks, density and animation", {
  chunks <- list(
    png_chunk("gAMA", be32(45455)),
    png_chunk(
      "cHRM",
      unlist(lapply(
        c(31270, 32900, 64000, 33000, 30000, 60000, 15000, 6000),
        be32
      ))
    ),
    png_chunk("sRGB", as.raw(1)),
    png_chunk("cICP", as.raw(c(9, 16, 0, 1))),
    png_chunk("pHYs", c(be32(2835), be32(2835), as.raw(1)))
  )
  p <- make_png(samples_for(2L, 3L, 3L, 255L), 3L, 2L, chunks_before = chunks)
  i <- pix_info(p)

  expect_identical(i$format, "png")
  expect_identical(c(i$width, i$height), c(3, 2))
  expect_identical(i$bits, 8L)
  expect_identical(i$colour_type, "rgb")
  expect_false(i$alpha)
  expect_false(i$interlaced)
  expect_false(i$animated)
  expect_equal(i$gamma, 0.45455)
  expect_identical(i$srgb, 1L)
  expect_equal(i$chrm[[1]], c(0.3127, 0.329, 0.64, 0.33, 0.3, 0.6, 0.15, 0.06))
  expect_identical(i$cicp[[1]], c(9L, 16L, 0L, 1L))
  expect_identical(c(i$density_x, i$density_y), c(2835, 2835))
  expect_identical(i$density_unit, 1L)
  expect_false(i$icc)
  expect_false(i$exif)
  expect_true(is.na(i$orientation))
  expect_true(is.na(i$qoi_linear))
})

test_that("absent PNG metadata is NA or NULL", {
  i <- pix_info(make_png(matrix(0L), 1L, 0L))
  expect_true(is.na(i$gamma))
  expect_true(is.na(i$srgb))
  expect_null(i$chrm[[1]])
  expect_null(i$cicp[[1]])
  expect_true(is.na(i$density_x))
  expect_identical(i$colour_type, "grey")
})

test_that("PNG iCCP inflates to the profile, bounded by max_metadata", {
  profile <- as.raw(rep(1:200, 50))
  iccp <- png_chunk(
    "iCCP",
    c(charToRaw("ICC"), as.raw(c(0, 0)), memCompress(profile, "gzip"))
  )
  p <- make_png(matrix(0L), 1L, 0L, chunks_before = list(iccp))
  expect_true(pix_info(p)$icc)
  expect_identical(pix_icc(p), profile)

  # 10,000 bytes inflated past a 5,000-byte cap, from a smaller stream.
  err <- expect_error(
    pix_icc(p, limits = pix_limits(max_metadata = 5000)),
    class = "zupix_limit_error"
  )
  expect_identical(err$limit, "max_metadata")
  # The size compared with the cap, inflated, not the compressed length.
  expect_gt(err$value, err$cap)
  expect_identical(err$cap, 5000)
})

test_that("PNG eXIf gives the EXIF block and orientation", {
  block <- exif_block(3L, big_endian = TRUE)
  p <- make_png(
    matrix(0L),
    1L,
    0L,
    chunks_before = list(png_chunk("eXIf", block))
  )
  expect_identical(pix_exif(p), block)
  expect_identical(pix_info(p)$orientation, 3L)
  expect_null(pix_icc(p))
})

test_that("a PNG metadata chunk with a bad CRC is a decode error", {
  p <- make_png(
    matrix(0L),
    1L,
    0L,
    chunks_before = list(png_chunk("gAMA", be32(45455)))
  )
  at <- grepRaw("gAMA", p) + 4L
  p[at] <- xor(p[at], as.raw(1))
  expect_error(pix_info(p), class = "zupix_decode_error")
})

test_that("JPEG markers give size, colour type, density, EXIF and ICC", {
  jpg <- fixture("rgb.jpg")
  i <- pix_info(jpg)
  expect_identical(i$format, "jpeg")
  expect_identical(c(i$width, i$height), c(16, 12))
  expect_identical(i$bits, 8L)
  expect_identical(i$colour_type, "ycbcr")
  expect_false(i$interlaced)
  expect_false(is.na(i$density_unit))
  expect_identical(pix_info(fixture("grey.jpg"))$colour_type, "grey")

  with_meta <- jpeg_with(
    jpg,
    jpeg_exif(exif_block(8L)),
    jpeg_icc(as.raw(1:250), 1L)
  )
  i <- pix_info(with_meta)
  expect_identical(i$orientation, 8L)
  expect_true(i$icc)
  expect_true(i$exif)
  expect_identical(pix_exif(with_meta), exif_block(8L))
})

test_that("JPEG ICC segments reassemble by sequence number", {
  profile <- as.raw(rep(0:255, 3))
  in_order <- jpeg_with(fixture("rgb.jpg"), jpeg_icc(profile, 3L))
  expect_identical(pix_icc(in_order), profile)

  segs <- jpeg_icc(profile, 3L)
  shuffled <- jpeg_with(fixture("rgb.jpg"), segs[[3]], segs[[1]], segs[[2]])
  expect_identical(pix_icc(shuffled), profile)
})

test_that("JPEG ICC segments with a gap, a repeat or a zero count fail", {
  jpg <- fixture("rgb.jpg")
  profile <- as.raw(rep(1:100, 3))
  gap <- jpeg_with(jpg, jpeg_icc(profile, 2L, seq = c(1L, 3L), count = 3L))
  repeat_seg <- jpeg_with(jpg, jpeg_icc(profile, 2L, seq = c(1L, 1L)))
  zero <- jpeg_with(jpg, jpeg_icc(profile, 1L, seq = 0L, count = 0L))
  for (bad in list(gap, repeat_seg, zero)) {
    expect_error(pix_info(bad), class = "zupix_decode_error")
    expect_error(pix_icc(bad), class = "zupix_decode_error")
    expect_error(pix_read(bad), class = "zupix_decode_error")
  }
})

test_that("an Adobe APP14 transform of 0 marks three components as RGB", {
  adobe <- jpeg_segment(
    0xee,
    c(charToRaw("Adobe"), be16(100), be16(0), be16(0), as.raw(0))
  )
  expect_identical(
    pix_info(jpeg_with(fixture("rgb.jpg"), adobe))$colour_type,
    "rgb"
  )
})

test_that("WebP chunks give size, alpha, ICC and EXIF", {
  i <- pix_info(fixture("lossy.webp"))
  expect_identical(c(i$format, i$colour_type), c("webp", "ycbcr"))
  expect_false(i$alpha)
  expect_true(pix_info(fixture("lossy-alpha.webp"))$alpha)
  expect_identical(pix_info(fixture("lossless.webp"))$colour_type, "rgb")
  expect_identical(pix_info(fixture("lossless-alpha.webp"))$colour_type, "rgba")

  profile <- as.raw(1:77)
  block <- exif_block(6L)
  w <- webp_extended(
    0x20 + 0x08,
    16L,
    12L,
    list(
      webp_chunk("ICCP", profile),
      webp_bitstream(fixture("lossy.webp")),
      webp_chunk("EXIF", block)
    )
  )
  expect_identical(pix_icc(w), profile)
  expect_identical(pix_exif(w), block)
  expect_identical(pix_info(w)$orientation, 6L)
  expect_identical(dim(pix_read(w, as = "integer")), c(12L, 16L, 3L))

  # Some writers keep JPEG's "Exif\0\0" prefix; it is skipped.
  w2 <- webp_extended(
    0x08,
    16L,
    12L,
    list(
      webp_bitstream(fixture("lossy.webp")),
      webp_chunk("EXIF", c(charToRaw("Exif"), as.raw(c(0, 0)), block))
    )
  )
  expect_identical(pix_exif(w2), block)
})

test_that("a RIFF size beyond the input is a decode error", {
  w <- fixture("lossy.webp")
  w[5:8] <- le32(length(w) * 2)
  expect_error(pix_info(w), class = "zupix_decode_error")
  expect_error(pix_read(w), class = "zupix_decode_error")
})

test_that("the container and the decoder must agree on the size", {
  # A VP8X canvas one pixel wider than its bitstream. Wuffs refuses this
  # one itself.
  w <- webp_extended(0, 17L, 12L, list(webp_bitstream(fixture("lossy.webp"))))
  expect_identical(pix_info(w)$width, 17)
  expect_error(pix_read(w), class = "zupix_decode_error")

  # A VP8L bitstream inside VP8X is handed to Wuffs as a simple file, which
  # Wuffs decodes at the bitstream's 16 x 12. Only zupix's own check sees
  # that the canvas says 17 x 12 (or 16 x 13).
  vp8l <- webp_bitstream(fixture("lossless.webp"))
  expect_identical(
    dim(pix_read(webp_extended(0, 16L, 12L, list(vp8l)), as = "integer")),
    c(12L, 16L, 3L)
  )
  for (size in list(c(17L, 12L), c(16L, 13L), c(15L, 12L))) {
    w <- webp_extended(0, size[[1]], size[[2]], list(vp8l))
    expect_identical(pix_info(w)$width, as.double(size[[1]]))
    err <- expect_error(pix_read(w), class = "zupix_decode_error")
    expect_identical(err$format, "webp")
  }
  # So does an animated file whose first frame's bitstream differs from the
  # ANMF frame and the canvas.
  anim <- webp_animated(17L, 12L, list(vp8l))
  expect_error(pix_read(anim), class = "zupix_decode_error")
})

test_that("QOI's colourspace byte is reported", {
  img <- array(1L, c(1L, 1L, 3L))
  expect_false(pix_info(make_qoi(img))$qoi_linear)
  expect_true(pix_info(make_qoi(img, colourspace = 1L))$qoi_linear)
  expect_identical(pix_info(make_qoi(img))$colour_type, "rgb")
})

test_that("EXIF offsets outside the block or at the header give no orientation", {
  ok <- exif_block(5L)
  expect_identical(
    pix_info(jpeg_with(fixture("rgb.jpg"), jpeg_exif(ok)))$orientation,
    5L
  )

  outside <- ok
  outside[5:8] <- le32(5000) # IFD0 beyond the block
  at_header <- ok
  at_header[5:8] <- le32(4) # IFD0 pointing into the TIFF header
  huge_count <- ok
  huge_count[9:10] <- le16(65535)
  bad_type <- ok
  bad_type[13:14] <- le16(4) # LONG, not SHORT
  for (b in list(outside, at_header, huge_count, bad_type, ok[1:9])) {
    jpg <- jpeg_with(fixture("rgb.jpg"), jpeg_exif(b))
    expect_true(is.na(pix_info(jpg)$orientation))
    expect_identical(pix_exif(jpg), b)
    expect_identical(dim(pix_read(jpg, orient = TRUE)), c(12L, 16L))
  }
})

test_that("pix_info() takes several paths, one row each", {
  dir <- withr::local_tempdir()
  files <- file.path(dir, c("a.png", "b.qoi", "c.jpg"))
  writeBin(make_png(matrix(0L, 2L, 5L), 5L, 0L), files[1])
  writeBin(make_qoi(array(0L, c(3L, 4L, 4L))), files[2])
  file.copy(test_path("fixtures", "rgb.jpg"), files[3])

  i <- pix_info(files)
  expect_s3_class(i, "data.frame")
  expect_identical(nrow(i), 3L)
  expect_identical(i$format, c("png", "qoi", "jpeg"))
  expect_identical(i$width, c(5, 4, 16))
  expect_identical(nrow(pix_info(character())), 0L)
})

test_that("metadata functions check `format` and the signature", {
  expect_error(
    pix_info(fixture("rgb.jpg"), format = "png"),
    class = "zupix_format_error"
  )
  expect_error(pix_icc(charToRaw("not an image")), class = "zupix_format_error")
  expect_error(
    pix_exif(fixture("rgb.jpg"), limits = 1),
    class = "zupix_input_error"
  )
})

test_that("metadata beyond max_metadata is a limit error", {
  jpg <- jpeg_with(fixture("rgb.jpg"), jpeg_icc(as.raw(rep(1:200, 10)), 2L))
  err <- expect_error(
    pix_info(jpg, limits = pix_limits(max_metadata = 1000)),
    class = "zupix_limit_error"
  )
  expect_identical(err$limit, "max_metadata")
  expect_error(
    pix_read(jpg, limits = pix_limits(max_metadata = 1000)),
    class = "zupix_limit_error"
  )
})

test_that("CMYK and YCCK JPEGs are reported and decode to RGB", {
  # libjpeg-turbo writes the Adobe APP14 marker with transform 0 for CMYK
  # and 2 for YCCK (tools/make-fixtures.R). The samples are Adobe's
  # inverted CMYK; RGB is each of C, M, Y times K, without colour
  # management (design §6.2).
  x <- col(matrix(0, 12L, 16L)) - 1
  y <- row(matrix(0, 12L, 16L)) - 1
  k <- 255 - 4 * (x + y)
  expected <- array(c(x * 16 * k, y * 20 * k, 128 * k) / 255, c(12L, 16L, 3L))
  for (kind in c("cmyk", "ycck")) {
    jpg <- fixture(paste0(kind, ".jpg"))
    i <- pix_info(jpg)
    expect_identical(i$colour_type, kind)
    expect_identical(c(i$width, i$height), c(16, 12))
    expect_false(i$alpha)
    rgb <- pix_read(jpg, as = "integer")
    expect_identical(dim(rgb), c(12L, 16L, 3L))
    err <- abs(rgb - expected)
    expect_lt(mean(err), 2, label = kind)
    expect_lt(max(err), if (kind == "cmyk") 3 else 12, label = kind)
    expect_s3_class(pix_read(jpg), "nativeRaster")
    # Channels are never removed, so a grey request is refused.
    expect_error(
      pix_read(jpg, as = "integer", channels = 1L),
      class = "zupix_input_error"
    )
  }
})

test_that("malformed PNG iCCP chunks are decode errors", {
  iccp <- function(payload) {
    make_png(
      matrix(0L),
      1L,
      0L,
      chunks_before = list(png_chunk("iCCP", payload))
    )
  }
  z <- memCompress(as.raw(1:50), "gzip")
  bad_header <- list(
    no_name = c(as.raw(c(0, 0)), z),
    long_name = c(charToRaw(strrep("n", 80)), as.raw(c(0, 0)), z),
    no_method = charToRaw("ICC"),
    method_1 = c(charToRaw("ICC"), as.raw(c(0, 1)), z)
  )
  for (payload in bad_header) {
    expect_error(pix_info(iccp(payload)), class = "zupix_decode_error")
    expect_error(pix_read(iccp(payload)), class = "zupix_decode_error")
  }
  # A well-formed header over a stream that does not inflate: only reading
  # the profile notices.
  broken <- iccp(c(charToRaw("ICC"), as.raw(c(0, 0)), z[1:6]))
  expect_true(pix_info(broken)$icc)
  expect_error(pix_icc(broken), class = "zupix_decode_error")
  garbage <- iccp(c(charToRaw("ICC"), as.raw(c(0, 0)), charToRaw("not zlib")))
  expect_error(pix_icc(garbage), class = "zupix_decode_error")
})

test_that("malformed JPEG markers are decode errors", {
  jpg <- fixture("rgb.jpg")
  sof <- grepRaw(as.raw(c(0xff, 0xc0)), jpg)
  # A stray byte where the next marker should be, after a comment segment
  # (right after SOI it would break the signature instead).
  no_ff <- jpeg_with(jpg, jpeg_segment(0xfe, charToRaw("hi")), as.raw(0x00))
  eoi <- jpeg_with(jpg, as.raw(c(0xff, 0xd9)))
  soi <- jpeg_with(jpg, as.raw(c(0xff, 0xd8)))
  no_components <- jpg
  no_components[sof + 9L] <- as.raw(0)
  too_many <- jpg
  too_many[sof + 9L] <- as.raw(4)
  segs <- jpeg_icc(as.raw(1:100), 2L)
  recount <- segs[[2]]
  recount[18L] <- as.raw(3) # the second segment claims three in all
  disagree <- jpeg_with(jpg, segs[[1]], recount)
  empty <- jpeg_with(
    jpg,
    jpeg_segment(0xe2, c(charToRaw("ICC_PROFILE"), as.raw(c(0, 1, 1))))
  )
  past_end <- c(jpg[1:2], as.raw(c(0xff, 0xfe, 0x7f, 0xff, 0x00)))
  cases <- list(
    no_ff,
    eoi,
    soi,
    past_end,
    no_components,
    too_many,
    disagree,
    empty
  )
  for (bad in cases) {
    expect_error(pix_info(bad), class = "zupix_decode_error")
    expect_error(pix_read(bad), class = "zupix_decode_error")
  }
})

test_that("malformed WebP chunks are decode errors", {
  lossy <- fixture("lossy.webp")
  long_chunk <- lossy
  long_chunk[17:20] <- le32(length(lossy)) # past the RIFF data
  frame <- webp_bitstream(lossy)
  frame[5:8] <- le32(length(frame) + 100) # past its ANMF chunk
  long_frame <- webp_animated(16L, 12L, list(frame))
  # Flagged as animated, with a bitstream but no ANMF frame.
  no_frames <- webp_extended(0x02, 16L, 12L, list(webp_bitstream(lossy)))
  expect_true(pix_info(no_frames)$animated)
  for (bad in list(long_chunk, long_frame)) {
    expect_error(pix_info(bad), class = "zupix_decode_error")
  }
  for (bad in list(long_chunk, long_frame, no_frames)) {
    expect_error(pix_read(bad), class = "zupix_decode_error")
  }
})

test_that("a QOI channel count other than 3 or 4 is a decode error", {
  q <- make_qoi(array(1L, c(1L, 1L, 3L)))
  for (ch in c(0L, 1L, 5L)) {
    q[13] <- as.raw(ch)
    expect_error(pix_info(q), class = "zupix_decode_error")
    expect_error(pix_read(q), class = "zupix_decode_error")
  }
})

test_that("a QOI header that qoi.h refuses is a decode error", {
  q <- make_qoi(array(1L, c(2L, 2L, 3L)))
  end <- as.raw(c(0, 0, 0, 0, 0, 0, 0, 1))
  colourspace <- q
  colourspace[14] <- as.raw(2)
  no_width <- c(q[1:4], be32(0), q[9:14], end)
  no_height <- c(q[1:8], be32(0), q[13:14], end)
  for (bad in list(colourspace, no_width, no_height)) {
    expect_error(pix_read(bad), class = "zupix_decode_error")
  }
})

test_that("the first of several ICC or EXIF blocks wins (design §6.4)", {
  first <- exif_block(6L)
  second <- exif_block(3L)
  profile <- as.raw(rep(1:9, 10))
  iccp <- function(x) {
    png_chunk(
      "iCCP",
      c(charToRaw("ICC"), as.raw(c(0, 0)), memCompress(x, "gzip"))
    )
  }
  p <- make_png(
    matrix(0L),
    1L,
    0L,
    chunks_before = list(
      png_chunk("eXIf", first),
      png_chunk("eXIf", second),
      iccp(profile),
      iccp(rev(profile))
    )
  )
  expect_identical(pix_exif(p), first)
  expect_identical(pix_info(p)$orientation, 6L)
  expect_identical(pix_icc(p), profile)

  jpg <- jpeg_with(
    fixture("rgb.jpg"),
    jpeg_exif(first),
    jpeg_exif(second)
  )
  expect_identical(pix_exif(jpg), first)
  expect_identical(pix_info(jpg)$orientation, 6L)

  w <- webp_extended(
    0x28,
    16L,
    12L,
    list(
      webp_chunk("ICCP", profile),
      webp_chunk("ICCP", rev(profile)),
      webp_bitstream(fixture("lossy.webp")),
      webp_chunk("EXIF", first),
      webp_chunk("EXIF", second)
    )
  )
  expect_identical(pix_icc(w), profile)
  expect_identical(pix_exif(w), first)
})

test_that("PNG metadata after IDAT: eXIf is read, colour chunks are not", {
  p <- make_png(samples_for(2L, 2L, 3L, 255L), 2L, 2L)
  iend <- length(p) - 11L
  after <- c(
    png_chunk("eXIf", exif_block(8L)),
    png_chunk("gAMA", be32(45455)),
    png_chunk("sRGB", as.raw(0)),
    png_chunk(
      "iCCP",
      c(charToRaw("ICC"), as.raw(c(0, 0)), memCompress(as.raw(1:9), "gzip"))
    )
  )
  late <- c(p[seq_len(iend - 1L)], after, p[iend:length(p)])
  i <- pix_info(late)
  expect_identical(i$orientation, 8L)
  expect_true(i$exif)
  expect_true(is.na(i$gamma))
  expect_true(is.na(i$srgb))
  expect_false(i$icc)
  expect_identical(pix_read(late, as = "integer"), pix_read(p, as = "integer"))
})

test_that("an EXIF block past max_metadata is a limit error in every format", {
  block <- c(exif_block(1L), raw(2000))
  files <- list(
    png = make_png(
      matrix(0L),
      1L,
      0L,
      chunks_before = list(
        png_chunk("eXIf", block)
      )
    ),
    jpeg = jpeg_with(fixture("rgb.jpg"), jpeg_exif(block)),
    webp = webp_extended(
      0x08,
      16L,
      12L,
      list(
        webp_bitstream(fixture("lossy.webp")),
        webp_chunk("EXIF", block)
      )
    )
  )
  lim <- pix_limits(max_metadata = 1000)
  for (f in files) {
    err <- expect_error(pix_exif(f, limits = lim), class = "zupix_limit_error")
    expect_identical(err$limit, "max_metadata")
    expect_identical(err$value, as.double(length(block)))
    expect_identical(err$cap, 1000)
    expect_error(pix_info(f, limits = lim), class = "zupix_limit_error")
    expect_identical(pix_exif(f), block)
  }
})
