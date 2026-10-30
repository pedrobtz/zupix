#!/usr/bin/env Rscript
# Writes the JPEG and WebP fixtures under tests/testthat/fixtures/, which the
# tests read instead of needing the jpeg and webp packages to make them. The
# images are small, seeded and smooth (so lossy codecs keep them close).
# Run from the package root after changing anything here; commit the output.
#
# PNG and QOI fixtures are built byte by byte in the tests themselves
# (helper-images.R), and metadata is spliced into these files there too.
stopifnot(requireNamespace("jpeg"), requireNamespace("webp"))

dir <- "tests/testthat/fixtures"
dir.create(dir, showWarnings = FALSE)

smooth <- function(h, w, channels, seed = 1L) {
  set.seed(seed)
  x <- rep(seq(0, 1, length.out = w), each = h)
  y <- rep(seq(0, 1, length.out = h), times = w)
  planes <- list(x, y, (x + y) / 2, 0.4 + 0.6 * x * y)
  array(unlist(planes[seq_len(channels)]), c(h, w, channels))
}

jpeg::writeJPEG(smooth(12, 16, 3), file.path(dir, "rgb.jpg"), quality = 0.9)
jpeg::writeJPEG(smooth(12, 16, 1)[, , 1], file.path(dir, "grey.jpg"),
                quality = 0.9)
webp::write_webp(smooth(12, 16, 3), file.path(dir, "lossy.webp"), quality = 90)
webp::write_webp(smooth(12, 16, 4), file.path(dir, "lossy-alpha.webp"),
                 quality = 90)
webp::write_webp(smooth(12, 16, 3), file.path(dir, "lossless.webp"),
                 quality = NA)
webp::write_webp(smooth(12, 16, 4), file.path(dir, "lossless-alpha.webp"),
                 quality = NA)
cat(list.files(dir), sep = "\n")
