# Builders for small test images, written byte by byte so that every PNG
# colour type, depth and tRNS combination can be made without another
# package. make_png() and make_qoi() return raw vectors.

# bitwXor() works on 32-bit signed integers; CRC values are kept as doubles
# in [0, 2^32) and xored in two 16-bit halves.
xor32 <- function(a, b) {
  hi <- bitwXor(as.integer(a %/% 65536), as.integer(b %/% 65536))
  lo <- bitwXor(as.integer(a %% 65536), as.integer(b %% 65536))
  hi * 65536 + lo
}

crc32_table <- local({
  tab <- numeric(256)
  for (n in 0:255) {
    c <- n
    for (k in 1:8) {
      c <- if (c %% 2 == 1) xor32(3988292384, c %/% 2) else c %/% 2
    }
    tab[n + 1] <- c
  }
  tab
})

crc32 <- function(bytes) {
  c <- 4294967295
  for (b in as.integer(bytes)) {
    idx <- bitwXor(as.integer(c %% 256), b)
    c <- xor32(crc32_table[idx + 1], c %/% 256)
  }
  xor32(c, 4294967295)
}

be32 <- function(x) {
  x <- as.double(x)
  as.raw(c(x %/% 2^24, (x %/% 2^16) %% 256, (x %/% 2^8) %% 256, x %% 256))
}

png_chunk <- function(type, data = raw()) {
  td <- c(charToRaw(type), data)
  c(be32(length(data)), td, be32(crc32(td)))
}

# A PNG from `samples`: an integer matrix with one row per image row and
# width * samples_per_pixel columns, holding sample values at `depth` bits
# (palette indices for colour type 3). Rows are written with filter 0.
make_png <- function(
  samples,
  width,
  colour_type,
  depth = 8L,
  palette = NULL,
  trns = NULL,
  chunks_before = list()
) {
  height <- nrow(samples)
  rows <- lapply(seq_len(height), function(y) {
    v <- samples[y, ]
    body <- if (depth == 16L) {
      as.raw(as.vector(rbind(v %/% 256L, v %% 256L)))
    } else if (depth == 8L) {
      as.raw(v)
    } else {
      per <- 8L / depth
      v <- c(v, rep(0L, (per - length(v) %% per) %% per))
      m <- matrix(v, nrow = per)
      as.raw(colSums(m * 2L^(depth * ((per - 1L):0))))
    }
    c(as.raw(0L), body)
  })
  ihdr <- c(
    be32(width),
    be32(height),
    as.raw(c(depth, colour_type, 0L, 0L, 0L))
  )
  out <- c(
    as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)),
    png_chunk("IHDR", ihdr)
  )
  for (ch in chunks_before) {
    out <- c(out, ch)
  }
  if (!is.null(palette)) {
    out <- c(out, png_chunk("PLTE", as.raw(palette)))
  }
  if (!is.null(trns)) {
    out <- c(out, png_chunk("tRNS", as.raw(trns)))
  }
  c(
    out,
    png_chunk("IDAT", memCompress(do.call(c, rows), "gzip")),
    png_chunk("IEND")
  )
}

# A QOI image from an RGB(A) integer array (height x width x 3 or 4),
# every pixel written as a QOI_OP_RGBA chunk.
make_qoi <- function(img, colourspace = 0L) {
  h <- dim(img)[1]
  w <- dim(img)[2]
  ch <- dim(img)[3]
  px <- vapply(
    seq_len(h * w),
    function(i) {
      y <- (i - 1L) %/% w + 1L
      x <- (i - 1L) %% w + 1L
      a <- if (ch == 4L) img[y, x, 4] else 255L
      c(img[y, x, 1], img[y, x, 2], img[y, x, 3], a)
    },
    integer(4)
  )
  ops <- as.vector(rbind(255L, px))
  c(
    charToRaw("qoif"),
    be32(w),
    be32(h),
    as.raw(c(ch, colourspace)),
    as.raw(ops),
    as.raw(c(0, 0, 0, 0, 0, 0, 0, 1))
  )
}

# Sample values for an image of the given size, deterministic.
samples_for <- function(height, width, per_pixel, max) {
  matrix(
    as.integer((seq_len(height * width * per_pixel) * 37L) %% (max + 1L)),
    nrow = height,
    byrow = TRUE
  )
}

# The expected R array (height x width x c, or a matrix) for row-major
# interleaved samples.
expected_array <- function(samples, height, width, channels) {
  a <- array(0L, c(height, width, channels))
  for (y in seq_len(height)) {
    m <- matrix(samples[y, ], nrow = channels)
    for (c in seq_len(channels)) {
      a[y, , c] <- m[c, ]
    }
  }
  if (channels == 1L) a[,, 1] else a
}

# Every PNG colour type and depth: the samples per pixel the file stores
# and the channels pix_read() reports.
png_cases <- function() {
  list(
    list(ct = 0L, depth = 1L, per = 1L, channels = 1L),
    list(ct = 0L, depth = 2L, per = 1L, channels = 1L),
    list(ct = 0L, depth = 4L, per = 1L, channels = 1L),
    list(ct = 0L, depth = 8L, per = 1L, channels = 1L),
    list(ct = 0L, depth = 16L, per = 1L, channels = 1L),
    list(ct = 2L, depth = 8L, per = 3L, channels = 3L),
    list(ct = 2L, depth = 16L, per = 3L, channels = 3L),
    list(ct = 4L, depth = 8L, per = 2L, channels = 2L),
    list(ct = 4L, depth = 16L, per = 2L, channels = 2L),
    list(ct = 6L, depth = 8L, per = 4L, channels = 4L),
    list(ct = 6L, depth = 16L, per = 4L, channels = 4L)
  )
}

# Sub-8-bit grey is scaled to 8 bits by bit replication, as PNG specifies.
scale_to_8 <- function(v, depth) {
  if (depth >= 8L) v else v * as.integer(255 %/% (2^depth - 1))
}

# A PNG that declares width x height but holds no pixel data: its header,
# an empty IDAT and IEND, 57 bytes.
declared_png <- function(width, height) {
  c(
    as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)),
    png_chunk("IHDR", c(be32(width), be32(height), as.raw(c(8, 6, 0, 0, 0)))),
    png_chunk("IDAT"),
    png_chunk("IEND")
  )
}

# ---- metadata splicing ------------------------------------------------------

fixture <- function(name) {
  readBin(
    test_path("fixtures", name),
    "raw",
    file.size(test_path("fixtures", name))
  )
}

be16 <- function(x) as.raw(c(x %/% 256, x %% 256))
le16 <- function(x) as.raw(c(x %% 256, x %/% 256))
le24 <- function(x) as.raw(c(x %% 256, (x %/% 256) %% 256, x %/% 65536))
le32 <- function(x) rev(be32(x))

# A minimal EXIF block (TIFF header onward) holding only IFD0's orientation.
exif_block <- function(orientation, big_endian = FALSE) {
  if (big_endian) {
    c(
      charToRaw("MM"),
      be16(42),
      be32(8),
      be16(1),
      be16(0x0112),
      be16(3),
      be32(1),
      be16(orientation),
      be16(0),
      be32(0)
    )
  } else {
    c(
      charToRaw("II"),
      le16(42),
      le32(8),
      le16(1),
      le16(0x0112),
      le16(3),
      le32(1),
      le16(orientation),
      le16(0),
      le32(0)
    )
  }
}

# A JPEG segment, and a JPEG with segments inserted right after SOI.
jpeg_segment <- function(marker, payload) {
  c(as.raw(c(0xff, marker)), be16(length(payload) + 2), payload)
}
jpeg_with <- function(jpg, ...) {
  c(jpg[1:2], unlist(list(...)), jpg[-(1:2)])
}
jpeg_exif <- function(block) {
  jpeg_segment(0xe1, c(charToRaw("Exif"), as.raw(c(0, 0)), block))
}
# APP2 ICC_PROFILE segments for `profile` split into `parts`, numbered
# `seq` (1..n by default) and declaring `count` segments.
jpeg_icc <- function(profile, parts = 1L, seq = seq_len(parts), count = parts) {
  pieces <- if (parts == 1L) {
    list(profile)
  } else {
    split(profile, cut(seq_along(profile), parts, labels = FALSE))
  }
  lapply(seq_along(pieces), function(i) {
    jpeg_segment(
      0xe2,
      c(charToRaw("ICC_PROFILE"), as.raw(c(0, seq[[i]], count)), pieces[[i]])
    )
  })
}

# A WebP chunk, padded to even length.
webp_chunk <- function(fourcc, payload) {
  c(
    charToRaw(fourcc),
    le32(length(payload)),
    payload,
    if (length(payload) %% 2) as.raw(0)
  )
}
riff <- function(chunks) {
  body <- c(charToRaw("WEBP"), unlist(chunks))
  c(charToRaw("RIFF"), le32(length(body)), body)
}
# The bitstream chunk (VP8 or VP8L) of a simple WebP file.
webp_bitstream <- function(webp) webp[-(1:12)]
# An extended WebP: VP8X with `flags` and the canvas size, then chunks.
webp_extended <- function(flags, width, height, chunks) {
  vp8x <- webp_chunk(
    "VP8X",
    c(as.raw(c(flags, 0, 0, 0)), le24(width - 1), le24(height - 1))
  )
  riff(c(list(vp8x), chunks))
}
# An animated WebP whose frames are given as their chunk bytes.
webp_animated <- function(
  width,
  height,
  frames,
  x = 0L,
  y = 0L,
  fw = width,
  fh = height
) {
  anim <- webp_chunk("ANIM", c(as.raw(c(255, 255, 255, 255)), le16(0)))
  anmf <- lapply(frames, function(f) {
    webp_chunk(
      "ANMF",
      c(
        le24(x %/% 2),
        le24(y %/% 2),
        le24(fw - 1),
        le24(fh - 1),
        le24(100),
        as.raw(0),
        f
      )
    )
  })
  webp_extended(0x02, width, height, c(list(anim), anmf))
}

# An APNG's acTL and the fcTL that makes IDAT its first frame.
apng_chunks <- function(width, height, frames = 1L) {
  list(
    png_chunk("acTL", c(be32(frames), be32(0))),
    png_chunk(
      "fcTL",
      c(
        be32(0),
        be32(width),
        be32(height),
        be32(0),
        be32(0),
        be16(1),
        be16(10),
        as.raw(c(0, 0))
      )
    )
  )
}

# A seeded random image with a `bits` attribute; a matrix for one channel.
random_image <- function(h, w, ch, bits, seed = 1L) {
  withr::local_seed(seed)
  a <- array(sample.int(2^bits, h * w * ch, replace = TRUE) - 1L, c(h, w, ch))
  if (ch == 1L) {
    a <- matrix(a, h, w)
  }
  attr(a, "bits") <- bits
  a
}

# A deterministic smooth 120 x 160 RGB image (integer, 8-bit), for lossy
# encoders, and its PSNR against a decoded copy.
smooth_rgb <- function(h = 120L, w = 160L) {
  x <- rep(seq(0, 1, length.out = w), each = h)
  y <- rep(seq(0, 1, length.out = h), times = w)
  a <- c(0.5 + 0.4 * sin(6 * x), 0.5 + 0.4 * cos(5 * y), (x + y) / 2)
  img <- array(as.integer(round(a * 255)), c(h, w, 3L))
  attr(img, "bits") <- 8L
  img
}
psnr <- function(decoded, original) {
  mse <- mean((as.numeric(decoded) - as.numeric(original))^2)
  10 * log10(255^2 / mse)
}
