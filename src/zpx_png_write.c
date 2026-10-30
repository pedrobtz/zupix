/* zupix's PNG writer (design §4.2, D4): IHDR, optional iCCP, sRGB and
 * eXIf, IDAT from zlib's deflate() over rows filtered by libpng's
 * minimum-sum-of-absolute-differences heuristic, and IEND, streamed to a
 * sink so no whole-file buffer is needed. Encoder input is the caller's own
 * array, so this is trusted input; sizes are still checked. */

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "zpx_core.h"

typedef struct {
  zpx_write_fn write;
  void *closure;
  int failed;
} out_t;

static void put(out_t *o, const uint8_t *p, size_t n) {
  if (!o->failed && n > 0 && o->write(o->closure, p, n) != 0) o->failed = 1;
}

static void be32(uint8_t *p, uint32_t v) {
  p[0] = (uint8_t) (v >> 24);
  p[1] = (uint8_t) (v >> 16);
  p[2] = (uint8_t) (v >> 8);
  p[3] = (uint8_t) v;
}

/* One chunk: length, type, data, CRC over type and data. */
static void chunk(out_t *o, const char *type, const uint8_t *data,
                  uint32_t n) {
  uint8_t head[8], crc[4];
  uLong c = crc32(0L, Z_NULL, 0);
  be32(head, n);
  memcpy(head + 4, type, 4);
  c = crc32(c, (const Bytef *) type, 4);
  if (n > 0) c = crc32(c, data, n);
  be32(crc, (uint32_t) c);
  put(o, head, 8);
  put(o, data, n);
  put(o, crc, 4);
}

/* Paeth predictor, as the PNG specification defines it. */
static int paeth(int a, int b, int c) {
  int p = a + b - c, pa = abs(p - a), pb = abs(p - b), pc = abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/* Filters `row` (with `prev`, NULL for the first row) by `type` into out. */
static void filter_row(int type, const uint8_t *row, const uint8_t *prev,
                       size_t n, size_t bpp, uint8_t *out) {
  for (size_t i = 0; i < n; i++) {
    int x = row[i];
    int a = i >= bpp ? row[i - bpp] : 0;
    int b = prev ? prev[i] : 0;
    int c = (prev && i >= bpp) ? prev[i - bpp] : 0;
    int v;
    switch (type) {
    case 0: v = x; break;
    case 1: v = x - a; break;
    case 2: v = x - b; break;
    case 3: v = x - ((a + b) >> 1); break;
    default: v = x - paeth(a, b, c); break;
    }
    out[i] = (uint8_t) v;
  }
}

/* Sum of the filtered bytes read as signed values, libpng's heuristic. */
static unsigned long cost(const uint8_t *p, size_t n) {
  unsigned long s = 0;
  for (size_t i = 0; i < n; i++) s += p[i] < 128 ? p[i] : 256 - p[i];
  return s;
}

/* Feeds `in` to deflate, emitting an IDAT chunk each time `zbuf` fills. */
static int deflate_into(out_t *o, z_stream *z, const uint8_t *in, size_t n,
                        int flush, uint8_t *zbuf, size_t zcap) {
  z->next_in = (Bytef *) in;
  z->avail_in = (uInt) n;
  for (;;) {
    int r;
    z->next_out = zbuf;
    z->avail_out = (uInt) zcap;
    r = deflate(z, flush);
    if (r == Z_STREAM_ERROR) return -1;
    if (zcap - z->avail_out > 0)
      chunk(o, "IDAT", zbuf, (uint32_t) (zcap - z->avail_out));
    if (flush == Z_FINISH ? r == Z_STREAM_END : z->avail_out != 0) break;
  }
  return 0;
}

zpx_status zpx_int_encode_png(const uint8_t *src, uint32_t width,
                              uint32_t height, int channels, int bits,
                              const zpx_png_opts *opts, zpx_write_fn write,
                              void *closure, const char **detail) {
  static const uint8_t sig[8] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a,
                                 '\n'};
  static const uint8_t colour_type[5] = {0, 0, 4, 2, 6};
  out_t o = {write, closure, 0};
  size_t bpp, row_len, zcap = 262144;
  uint8_t ihdr[13], *rows = NULL, *cand = NULL, *zbuf = NULL;
  z_stream z;
  zpx_status s = ZPX_OK;
  int level = opts ? opts->compression : 6;

  if (channels < 1 || channels > 4 || (bits != 8 && bits != 16) ||
      width == 0 || height == 0 || width > 0x7fffffffu ||
      height > 0x7fffffffu || level < 0 || level > 9) {
    *detail = "invalid PNG dimensions, channels, depth or compression";
    return ZPX_ERR_ARGUMENT;
  }
  bpp = (size_t) channels * (bits / 8);
  if (width > (SIZE_MAX - 1) / bpp) return ZPX_ERR_ENCODE;
  row_len = (size_t) width * bpp;

  /* Two rows of big-endian samples (this and the previous), and the five
   * filter candidates each with its filter-type byte. */
  rows = (uint8_t *) malloc(2 * row_len);
  cand = (uint8_t *) malloc(5 * (row_len + 1));
  zbuf = (uint8_t *) malloc(zcap);
  if (!rows || !cand || !zbuf) {
    free(rows); free(cand); free(zbuf);
    return ZPX_ERR_MEMORY;
  }
  memset(&z, 0, sizeof z);
  if (deflateInit(&z, level) != Z_OK) {
    free(rows); free(cand); free(zbuf);
    return ZPX_ERR_MEMORY;
  }

  put(&o, sig, 8);
  be32(ihdr, width);
  be32(ihdr + 4, height);
  ihdr[8] = (uint8_t) bits;
  ihdr[9] = colour_type[channels];
  ihdr[10] = ihdr[11] = ihdr[12] = 0;
  chunk(&o, "IHDR", ihdr, 13);

  if (opts && opts->icc && opts->icc_len > 0) {
    /* "ICC profile", NUL, compression method 0, the zlib stream. */
    uLongf clen = compressBound((uLong) opts->icc_len);
    uint8_t *iccp = (uint8_t *) malloc(13 + clen);
    if (!iccp) { s = ZPX_ERR_MEMORY; goto done; }
    memcpy(iccp, "ICC profile\0\0", 13);
    if (compress2(iccp + 13, &clen, opts->icc, (uLong) opts->icc_len, 9) !=
            Z_OK ||
        13 + clen > 0x7fffffffu) {
      free(iccp);
      *detail = "the ICC profile could not be compressed";
      s = ZPX_ERR_ENCODE;
      goto done;
    }
    chunk(&o, "iCCP", iccp, (uint32_t) (13 + clen));
    free(iccp);
  }
  if (opts && opts->srgb >= 0) {
    uint8_t intent = (uint8_t) opts->srgb;
    chunk(&o, "sRGB", &intent, 1);
  }
  if (opts && opts->exif && opts->exif_len > 0) {
    if (opts->exif_len > 0x7fffffffu) {
      *detail = "the EXIF block is too large for a PNG chunk";
      s = ZPX_ERR_ENCODE;
      goto done;
    }
    chunk(&o, "eXIf", opts->exif, (uint32_t) opts->exif_len);
  }

  for (uint32_t y = 0; y < height; y++) {
    uint8_t *cur = rows + (y & 1) * row_len;
    uint8_t *prev = y > 0 ? rows + ((y - 1) & 1) * row_len : NULL;
    const uint8_t *in = src + (size_t) y * row_len;
    int best = 0;
    unsigned long best_cost = 0;
    /* PNG stores 16-bit samples big-endian. */
    if (bits == 8) {
      memcpy(cur, in, row_len);
    } else {
      const uint16_t *s16 = (const uint16_t *) (const void *) in;
      for (size_t i = 0; i < row_len / 2; i++) {
        cur[2 * i] = (uint8_t) (s16[i] >> 8);
        cur[2 * i + 1] = (uint8_t) s16[i];
      }
    }
    /* Level 0 stores; filtering would only cost time. */
    for (int t = 0; t < (level == 0 ? 1 : 5); t++) {
      uint8_t *c = cand + (size_t) t * (row_len + 1);
      unsigned long k;
      c[0] = (uint8_t) t;
      filter_row(t, cur, prev, row_len, bpp, c + 1);
      k = cost(c + 1, row_len);
      if (t == 0 || k < best_cost) {
        best = t;
        best_cost = k;
      }
    }
    if (deflate_into(&o, &z, cand + (size_t) best * (row_len + 1),
                     row_len + 1, Z_NO_FLUSH, zbuf, zcap) != 0) {
      s = ZPX_ERR_ENCODE;
      goto done;
    }
    if (o.failed) break;
  }
  if (!o.failed &&
      deflate_into(&o, &z, NULL, 0, Z_FINISH, zbuf, zcap) != 0) {
    s = ZPX_ERR_ENCODE;
    goto done;
  }
  chunk(&o, "IEND", NULL, 0);
  if (o.failed) s = ZPX_ERR_SINK;

done:
  deflateEnd(&z);
  free(rows);
  free(cand);
  free(zbuf);
  return s;
}
