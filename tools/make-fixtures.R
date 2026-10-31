#!/usr/bin/env Rscript
# Writes the JPEG and WebP fixtures under tests/testthat/fixtures/, which the
# tests read instead of needing the jpeg and webp packages to make them. The
# images are small, seeded and smooth (so lossy codecs keep them close).
# Run from the package root after changing anything here; commit the output.
#
# PNG and QOI fixtures are built byte by byte in the tests themselves
# (helper-images.R), and metadata is spliced into these files there too.
#
# The four-component JPEGs (cmyk.jpg, ycck.jpg) need a compressor that takes
# CMYK input, which neither package offers: a small C program is compiled
# against the system's libjpeg-turbo (LIBJPEG_FLAGS, else pkg-config, else
# /usr/local) and writes them.
# libjpeg-turbo adds the Adobe APP14 marker itself, with transform 0 for CMYK
# and 2 for YCCK.
stopifnot(
  requireNamespace("jpeg"),
  requireNamespace("webp"),
  requireNamespace("qoi")
)

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

# A QOI written by the qoi package (qoi.h), for the hostile suite: a smooth
# RGBA image with a flat block, so it holds runs as well as small deltas.
q <- array(as.integer(round(smooth(12, 16, 4) * 255)), c(12, 16, 4))
q[1:6, 1:8, ] <- 200L
writeBin(qoi::writeQOI(q), file.path(dir, "smooth.qoi"))

cmyk_c <- r"(
#include <stdio.h>
#include <stdlib.h>
#include <jpeglib.h>
/* argv: out.jpg, "cmyk" or "ycck". A smooth 12 x 16 CMYK image. */
int main(int argc, char **argv) {
  struct jpeg_compress_struct c;
  struct jpeg_error_mgr e;
  JSAMPLE row[16 * 4];
  FILE *f = fopen(argv[1], "wb");
  if (f == NULL || argc != 3) return 1;
  c.err = jpeg_std_error(&e);
  jpeg_create_compress(&c);
  jpeg_stdio_dest(&c, f);
  c.image_width = 16;
  c.image_height = 12;
  c.input_components = 4;
  c.in_color_space = JCS_CMYK;
  jpeg_set_defaults(&c);
  jpeg_set_colorspace(&c, argv[2][0] == 'y' ? JCS_YCCK : JCS_CMYK);
  jpeg_set_quality(&c, 95, TRUE);
  jpeg_start_compress(&c, TRUE);
  for (int y = 0; y < 12; y++) {
    JSAMPROW r = row;
    for (int x = 0; x < 16; x++) {
      row[4 * x] = (JSAMPLE) (x * 16);
      row[4 * x + 1] = (JSAMPLE) (y * 20);
      row[4 * x + 2] = (JSAMPLE) (128);
      row[4 * x + 3] = (JSAMPLE) (255 - 4 * (x + y));
    }
    jpeg_write_scanlines(&c, &r, 1);
  }
  jpeg_finish_compress(&c);
  jpeg_destroy_compress(&c);
  return fclose(f) != 0;
}
)"
src <- tempfile(fileext = ".c")
exe <- tempfile()
writeLines(cmyk_c, src)
flags <- Sys.getenv("LIBJPEG_FLAGS")
if (!nzchar(flags)) {
  flags <- if (nzchar(Sys.which("pkg-config"))) {
    system2("pkg-config", c("--cflags", "--libs", "libjpeg"), stdout = TRUE)
  } else {
    "-I/usr/local/include -L/usr/local/lib -ljpeg"
  }
}
stopifnot(system(paste("cc -o", exe, src, flags)) == 0)
for (kind in c("cmyk", "ycck")) {
  out <- file.path(dir, paste0(kind, ".jpg"))
  stopifnot(system2(exe, c(out, kind)) == 0)
}

cat(list.files(dir), sep = "\n")
