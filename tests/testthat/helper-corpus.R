# Helpers for test-conformance.R and test-hostile.R. In a helper file so
# every testthat worker, in any shuffled order, has them.

pngsuite <- function() {
  list.files(test_path("corpus", "pngsuite"), "[.]png$", full.names = TRUE)
}

# PPM or PGM from djpeg, as an integer array.
read_pnm <- function(f) {
  b <- readBin(f, "raw", file.size(f))
  nl <- which(b == as.raw(10))[3]
  hdr <- strsplit(rawToChar(b[seq_len(nl)]), "[[:space:]]+")[[1]]
  ch <- if (hdr[1] == "P6") 3L else 1L
  a <- aperm(
    array(
      as.integer(b[(nl + 1):length(b)]),
      c(ch, as.integer(hdr[2]), as.integer(hdr[3]))
    ),
    c(3L, 2L, 1L)
  )
  if (ch == 1L) a[,, 1] else a
}

corpus_dir <- function(name) {
  root <- Sys.getenv("ZUPIX_CORPUS")
  skip_if(!nzchar(root), "ZUPIX_CORPUS is not set")
  d <- file.path(root, name)
  skip_if(!dir.exists(d), paste(d, "does not exist"))
  d
}

hostile_files <- function() {
  c(
    list.files(test_path("fixtures"), full.names = TRUE),
    list.files(test_path("corpus", "pngsuite"), "[.]png$", full.names = TRUE),
    list.files(
      test_path("corpus", "libjpeg-turbo"),
      "[.]jpg$",
      full.names = TRUE
    )
  )
}

# Every offset to cut `n` bytes at: all of the first 4,096 and 64 random
# later ones in full mode; a sample otherwise.
cut_points <- function(n, full) {
  head <- seq_len(min(n, 4096L)) - 1L
  if (!full) {
    head <- unique(c(head[head < 16L], head[seq(1L, length(head), 509L)]))
  }
  tail <- if (n > 4096L) {
    sample(4097L:n, min(if (full) 64L else 2L, n - 4096L))
  } else {
    integer()
  }
  c(head, tail)
}

# The conditions a damaged file may raise. Anything else, an internal or
# memory error included, is a zupix bug.
hostile_classes <- c(
  "zupix_decode_error",
  "zupix_format_error",
  "zupix_unsupported_error",
  "zupix_limit_error"
)

# Runs `f(bytes)` and names anything that is neither success nor one of
# hostile_classes. One expectation per file keeps the suite fast.
not_clean <- function(f, bytes, where) {
  tryCatch(
    {
      f(bytes)
      NULL
    },
    error = function(e) {
      if (inherits(e, hostile_classes)) {
        return(NULL)
      }
      paste(where, class(e)[[1]], conditionMessage(e))
    }
  )
}
