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
