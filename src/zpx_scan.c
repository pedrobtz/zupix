/* zupix's own container scanners (design §6.4, D12): PNG chunks, JPEG
 * markers up to the first SOS, RIFF chunks, the QOI header and EXIF IFD0.
 * They read metadata Wuffs does not report and check what Wuffs will be
 * told. Each is one bounded pass with no recursion: every step consumes at
 * least one byte or one chunk frame, every read is preceded by a length
 * check against the bytes that remain, and sizes are compared in size_t
 * after checking they fit. These are zupix's only hand-written parsers of
 * untrusted input; Stage 7 fuzzes them. */

#include <string.h>
#include <zlib.h>

#include "zpx_core.h"

static uint32_t be16(const uint8_t *p) {
  return ((uint32_t) p[0] << 8) | p[1];
}
static uint32_t be32(const uint8_t *p) {
  return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16) |
         ((uint32_t) p[2] << 8) | p[3];
}
static uint32_t le16(const uint8_t *p) {
  return (uint32_t) p[0] | ((uint32_t) p[1] << 8);
}
static uint32_t le24(const uint8_t *p) {
  return (uint32_t) p[0] | ((uint32_t) p[1] << 8) | ((uint32_t) p[2] << 16);
}
static uint32_t le32(const uint8_t *p) {
  return le24(p) | ((uint32_t) p[3] << 24);
}

static zpx_status fail(const char **detail, const char *why) {
  *detail = why;
  return ZPX_ERR_DECODE;
}

static zpx_status metadata_cap(const zpx_meta *m, const zpx_limits *limits,
                               const char **detail) {
  if ((uint64_t) m->icc_len + (uint64_t) m->exif_len > limits->max_metadata) {
    *detail = "metadata exceeds max_metadata";
    return ZPX_ERR_LIMIT;
  }
  return ZPX_OK;
}

/* ---- PNG -------------------------------------------------------------- */

static int png_depth_ok(uint8_t ct, uint8_t d) {
  switch (ct) {
  case 0: return d == 1 || d == 2 || d == 4 || d == 8 || d == 16;
  case 3: return d == 1 || d == 2 || d == 4 || d == 8;
  case 2: case 4: case 6: return d == 8 || d == 16;
  default: return 0;
  }
}

static zpx_status scan_png(const uint8_t *buf, size_t len, zpx_meta *m,
                           const char **detail) {
  size_t pos = 8;
  int first = 1, seen_idat = 0, trns = 0;
  uint8_t ct = 0;

  for (;;) {
    uint32_t n;
    const uint8_t *type, *d;
    if (len - pos < 12) return fail(detail, "PNG ends before its IEND chunk");
    n = be32(buf + pos);
    type = buf + pos + 4;
    d = buf + pos + 8;
    if (n > 0x7fffffffu || (size_t) n > len - pos - 12)
      return fail(detail, "PNG chunk length runs past the end of the input");

    if (first) {
      if (memcmp(type, "IHDR", 4) != 0 || n != 13)
        return fail(detail, "PNG does not start with a 13-byte IHDR chunk");
      first = 0;
    }
    /* Check the CRC of every chunk read here; IDAT is left to Wuffs. */
    if (memcmp(type, "IDAT", 4) != 0) {
      uLong crc = crc32(0L, Z_NULL, 0);
      crc = crc32(crc, type, (uInt) (n + 4));
      if ((uint32_t) crc != be32(d + n))
        return fail(detail, "PNG chunk has a bad CRC");
    }

    if (memcmp(type, "IHDR", 4) == 0) {
      m->width = be32(d);
      m->height = be32(d + 4);
      m->bits = d[8];
      ct = d[9];
      if (!png_depth_ok(ct, m->bits))
        return fail(detail, "PNG colour type and bit depth are invalid");
      if (d[12] > 1) return fail(detail, "PNG interlace method is invalid");
      m->interlaced = d[12] == 1;
    } else if (memcmp(type, "IDAT", 4) == 0) {
      seen_idat = 1;
    } else if (memcmp(type, "IEND", 4) == 0) {
      if (!seen_idat) return fail(detail, "PNG has no IDAT chunk");
      break;
    } else if (seen_idat) {
      /* Metadata after IDAT: PNG allows eXIf there. */
      if (memcmp(type, "eXIf", 4) == 0 && m->exif_len == 0) {
        m->exif_off = (size_t) (d - buf);
        m->exif_len = n;
      }
    } else if (memcmp(type, "tRNS", 4) == 0) {
      trns = 1;
    } else if (memcmp(type, "acTL", 4) == 0) {
      m->animated = 1;
    } else if (memcmp(type, "gAMA", 4) == 0 && n == 4) {
      m->gamma = be32(d) / 100000.0;
    } else if (memcmp(type, "cHRM", 4) == 0 && n == 32) {
      m->has_chrm = 1;
      for (int i = 0; i < 8; i++) m->chrm[i] = be32(d + 4 * i) / 100000.0;
    } else if (memcmp(type, "sRGB", 4) == 0 && n == 1) {
      m->srgb = d[0];
    } else if (memcmp(type, "cICP", 4) == 0 && n == 4) {
      m->has_cicp = 1;
      memcpy(m->cicp, d, 4);
    } else if (memcmp(type, "pHYs", 4) == 0 && n == 9) {
      m->density_x = be32(d);
      m->density_y = be32(d + 4);
      m->density_unit = d[8] == 1 ? 1 : 0;
    } else if (memcmp(type, "iCCP", 4) == 0 && m->icc_len == 0) {
      /* A 1-79 byte name, NUL, compression method 0, a zlib stream. */
      size_t k = 0;
      while (k < n && k < 80 && d[k] != 0) k++;
      if (k == 0 || k >= 80 || k + 2 > n || d[k + 1] != 0)
        return fail(detail, "PNG iCCP chunk is malformed");
      m->icc_off = (size_t) (d - buf) + k + 2;
      m->icc_len = n - (k + 2);
      m->icc_compressed = 1;
    } else if (memcmp(type, "eXIf", 4) == 0 && m->exif_len == 0) {
      m->exif_off = (size_t) (d - buf);
      m->exif_len = n;
    }
    pos += 12 + (size_t) n;
  }

  m->alpha = ct == 4 || ct == 6 || trns;
  switch (ct) {
  case 0: m->colour_type = ZPX_CT_GREY; m->channels = trns ? 2 : 1; break;
  case 2: m->colour_type = ZPX_CT_RGB; m->channels = trns ? 4 : 3; break;
  case 3: m->colour_type = ZPX_CT_PALETTE; m->channels = trns ? 4 : 3; break;
  case 4: m->colour_type = ZPX_CT_GREY_ALPHA; m->channels = 2; break;
  default: m->colour_type = ZPX_CT_RGBA; m->channels = 4; break;
  }
  return ZPX_OK;
}

/* ---- JPEG ------------------------------------------------------------- */

/* The payload of every APP2 ICC_PROFILE segment, by sequence number. */
typedef struct {
  int count;
  size_t off[256], len[256];
} icc_segments;

/* Walks the markers from SOI to the first SOS. With `segs` non-NULL,
 * collects ICC segments into it; with `m` non-NULL, fills the metadata. */
static zpx_status walk_jpeg(const uint8_t *buf, size_t len, zpx_meta *m,
                            icc_segments *segs, const char **detail) {
  size_t pos = 2;
  int seen_sof = 0, adobe = -1, ncomp = 0;

  if (segs) {
    segs->count = 0;
    memset(segs->len, 0, sizeof segs->len);
  }
  for (;;) {
    uint8_t mk;
    size_t seg;
    const uint8_t *p;
    /* A marker is 0xFF, any number of 0xFF fill bytes, then its code. */
    if (pos >= len || buf[pos] != 0xff)
      return fail(detail, "JPEG marker expected");
    while (pos < len && buf[pos] == 0xff) pos++;
    if (pos >= len) return fail(detail, "JPEG ends before its first SOS");
    mk = buf[pos++];
    if (mk == 0x01 || (mk >= 0xd0 && mk <= 0xd7)) continue; /* no length */
    if (mk == 0xd8 || mk == 0xd9)
      return fail(detail, "JPEG ends before its first SOS");
    if (len - pos < 2) return fail(detail, "JPEG segment is truncated");
    seg = be16(buf + pos);
    if (seg < 2 || seg > len - pos)
      return fail(detail, "JPEG segment length runs past the end");
    p = buf + pos + 2;
    seg -= 2; /* payload bytes at p */

    if (mk == 0xda) {
      if (!seen_sof) return fail(detail, "JPEG has SOS before SOF");
      break;
    }
    if (mk >= 0xc0 && mk <= 0xcf && mk != 0xc4 && mk != 0xc8 && mk != 0xcc) {
      if (!seen_sof) {
        if (seg < 6) return fail(detail, "JPEG SOF segment is truncated");
        ncomp = p[5];
        if (seg < 6 + 3 * (size_t) ncomp || ncomp == 0)
          return fail(detail, "JPEG SOF segment is truncated");
        if (m) {
          m->bits = p[0];
          m->height = be16(p + 1);
          m->width = be16(p + 3);
          m->interlaced = mk == 0xc2 || mk == 0xc6 || mk == 0xca ||
                          mk == 0xce;
        }
        seen_sof = 1;
      }
    } else if (mk == 0xe0 && seg >= 12 && memcmp(p, "JFIF\0", 5) == 0) {
      if (m && m->density_unit < 0) {
        m->density_unit = p[7] <= 2 ? p[7] : 0;
        m->density_x = be16(p + 8);
        m->density_y = be16(p + 10);
      }
    } else if (mk == 0xe1 && seg >= 6 && memcmp(p, "Exif\0\0", 6) == 0) {
      if (m && m->exif_len == 0) {
        m->exif_off = (size_t) (p - buf) + 6;
        m->exif_len = seg - 6;
      }
    } else if (mk == 0xe2 && seg >= 14 && memcmp(p, "ICC_PROFILE\0", 12) == 0) {
      int seq = p[12], count = p[13];
      icc_segments *s = segs;
      if (count == 0 || seq == 0 || seq > count)
        return fail(detail, "JPEG ICC profile segment numbering is invalid");
      if (m) {
        if (m->icc_segments == 0) {
          m->icc_segments = count;
          m->icc_off = (size_t) (p - buf) + 14;
        } else if (m->icc_segments != count) {
          return fail(detail, "JPEG ICC profile segments disagree on count");
        }
        m->icc_len += seg - 14;
      }
      if (s) {
        if (s->count == 0) s->count = count;
        if (s->count != count)
          return fail(detail, "JPEG ICC profile segments disagree on count");
        if (s->len[seq] != 0)
          return fail(detail, "JPEG ICC profile segment is repeated");
        s->off[seq] = (size_t) (p - buf) + 14;
        s->len[seq] = seg - 14;
        if (s->len[seq] == 0)
          return fail(detail, "JPEG ICC profile segment is empty");
      }
    } else if (mk == 0xee && seg >= 12 && memcmp(p, "Adobe", 5) == 0) {
      adobe = p[11];
    }
    pos += 2 + seg;
  }

  if (segs && segs->count > 0) {
    for (int i = 1; i <= segs->count; i++)
      if (segs->len[i] == 0)
        return fail(detail, "JPEG ICC profile has a missing segment");
  }
  if (m) {
    m->alpha = 0;
    if (ncomp == 1) {
      m->colour_type = ZPX_CT_GREY;
      m->channels = 1;
    } else if (ncomp == 3) {
      m->colour_type = adobe == 0 ? ZPX_CT_RGB : ZPX_CT_YCBCR;
      m->channels = 3;
    } else if (ncomp == 4) {
      /* Decoded to RGB through Wuffs's own conversion (design §6.2, Q3). */
      m->colour_type = adobe == 2 ? ZPX_CT_YCCK : ZPX_CT_CMYK;
      m->channels = 3;
    } else {
      m->colour_type = ZPX_CT_UNKNOWN;
      m->channels = 3;
    }
  }
  return ZPX_OK;
}

/* ---- WebP ------------------------------------------------------------- */

/* Reads a VP8 or VP8L bitstream header; sets *w, *h and *alpha. */
static int webp_bitstream(const uint8_t *fourcc, const uint8_t *p, size_t n,
                          uint32_t *w, uint32_t *h, int *alpha, int *lossy) {
  if (memcmp(fourcc, "VP8 ", 4) == 0) {
    if (n < 10 || (p[0] & 1) != 0 || p[3] != 0x9d || p[4] != 0x01 ||
        p[5] != 0x2a)
      return 0;
    *w = le16(p + 6) & 0x3fff;
    *h = le16(p + 8) & 0x3fff;
    *alpha = 0;
    *lossy = 1;
    return 1;
  }
  if (memcmp(fourcc, "VP8L", 4) == 0) {
    uint32_t b;
    if (n < 5 || p[0] != 0x2f) return 0;
    b = le32(p + 1);
    *w = (b & 0x3fff) + 1;
    *h = ((b >> 14) & 0x3fff) + 1;
    *alpha = (b >> 28) & 1;
    *lossy = 0;
    return 1;
  }
  return 0;
}

static zpx_status scan_webp(const uint8_t *buf, size_t len, zpx_meta *m,
                            const char **detail) {
  size_t end, pos = 12;
  uint32_t riff;
  int vp8x = 0, seen_bits = 0, lossy = 0, bits_alpha = 0, flags = 0;
  uint32_t bw = 0, bh = 0;
  size_t vp8l_off = 0, vp8l_len = 0;

  if (len < 20) return fail(detail, "WebP is truncated");
  riff = le32(buf + 4);
  if (riff < 4 || (size_t) riff > len - 8)
    return fail(detail, "WebP RIFF size runs past the end of the input");
  end = 8 + (size_t) riff;

  while (end - pos >= 8) {
    const uint8_t *fourcc = buf + pos, *p = buf + pos + 8;
    size_t n = le32(buf + pos + 4), padded;
    if (n > end - pos - 8)
      return fail(detail, "WebP chunk runs past the RIFF data");
    padded = n + (n & 1);
    if (pos == 12 && memcmp(fourcc, "VP8X", 4) == 0) {
      if (n < 10) return fail(detail, "WebP VP8X chunk is truncated");
      vp8x = 1;
      flags = p[0];
      m->width = le24(p + 4) + 1;
      m->height = le24(p + 7) + 1;
      m->animated = (flags & 0x02) != 0;
    } else if (pos == 12 && !webp_bitstream(fourcc, p, n, &bw, &bh,
                                            &bits_alpha, &lossy)) {
      return fail(detail, "WebP does not start with VP8, VP8L or VP8X");
    } else if (pos == 12) {
      seen_bits = 1;
      m->width = bw;
      m->height = bh;
    } else if (memcmp(fourcc, "ICCP", 4) == 0 && m->icc_len == 0) {
      m->icc_off = (size_t) (p - buf);
      m->icc_len = n;
    } else if (memcmp(fourcc, "EXIF", 4) == 0 && m->exif_len == 0) {
      size_t skip = n >= 6 && memcmp(p, "Exif\0\0", 6) == 0 ? 6 : 0;
      m->exif_off = (size_t) (p - buf) + skip;
      m->exif_len = n - skip;
    } else if (memcmp(fourcc, "ANMF", 4) == 0 && m->frame_len == 0) {
      /* 16 bytes of frame header, then the frame's own chunks. */
      size_t q;
      if (n < 16 + 8) return fail(detail, "WebP ANMF chunk is truncated");
      m->frame_x = 2 * le24(p);
      m->frame_y = 2 * le24(p + 3);
      m->frame_w = le24(p + 6) + 1;
      m->frame_h = le24(p + 9) + 1;
      m->frame_off = (size_t) (p - buf) + 16;
      m->frame_len = n - 16;
      for (q = 16; n - q >= 8;) {
        size_t k = le32(p + q + 4);
        if (k > n - q - 8)
          return fail(detail, "WebP frame chunk runs past its ANMF chunk");
        if (memcmp(p + q, "ALPH", 4) == 0) m->frame_alph = 1;
        if (!seen_bits && webp_bitstream(p + q, p + q + 8, k, &bw, &bh,
                                         &bits_alpha, &lossy))
          seen_bits = 1;
        q += 8 + k + (k & 1);
        if (q > n) break;
      }
    } else if (vp8x && !seen_bits &&
               webp_bitstream(fourcc, p, n, &bw, &bh, &bits_alpha, &lossy)) {
      seen_bits = 1;
      if (!lossy) {
        vp8l_off = pos;
        vp8l_len = 8 + padded;
        if (vp8l_len > end - pos) vp8l_len = 8 + n;
      }
    }
    if (padded > end - pos - 8) break; /* an odd last chunk without pad */
    pos += 8 + padded;
  }
  if (!seen_bits) return fail(detail, "WebP has no VP8 or VP8L bitstream");
  if (vp8x && !m->animated && !lossy && vp8l_off > 0) {
    m->webp_rebuild = 1;
    m->frame_off = vp8l_off;
    m->frame_len = vp8l_len;
    m->frame_x = m->frame_y = 0;
    m->frame_w = m->width;
    m->frame_h = m->height;
    m->frame_alph = 0;
  }

  m->bits = 8;
  /* An animated file's alpha flag is the writer's to set; a first frame
   * that carries ALPH or a VP8L alpha bit counts too. */
  m->alpha = (vp8x && (flags & 0x10) != 0) || bits_alpha || m->frame_alph;
  m->channels = m->alpha ? 4 : 3;
  m->colour_type = lossy ? ZPX_CT_YCBCR : (m->alpha ? ZPX_CT_RGBA : ZPX_CT_RGB);
  return ZPX_OK;
}

size_t zpx_int_webp_first_frame(const uint8_t *buf, const zpx_meta *m,
                                uint8_t *dst) {
  size_t n = 12, body;
  memcpy(dst, "RIFF\0\0\0\0WEBP", 12);
  if (m->frame_alph) {
    /* VP8X with only the alpha flag, canvas = the frame. */
    memcpy(dst + n, "VP8X", 4);
    dst[n + 4] = 10; dst[n + 5] = dst[n + 6] = dst[n + 7] = 0;
    memset(dst + n + 8, 0, 10);
    dst[n + 8] = 0x10;
    dst[n + 12] = (uint8_t) ((m->frame_w - 1) & 0xff);
    dst[n + 13] = (uint8_t) (((m->frame_w - 1) >> 8) & 0xff);
    dst[n + 14] = (uint8_t) (((m->frame_w - 1) >> 16) & 0xff);
    dst[n + 15] = (uint8_t) ((m->frame_h - 1) & 0xff);
    dst[n + 16] = (uint8_t) (((m->frame_h - 1) >> 8) & 0xff);
    dst[n + 17] = (uint8_t) (((m->frame_h - 1) >> 16) & 0xff);
    n += 18;
  }
  memcpy(dst + n, buf + m->frame_off, m->frame_len);
  n += m->frame_len;
  body = n - 8;
  dst[4] = (uint8_t) (body & 0xff);
  dst[5] = (uint8_t) ((body >> 8) & 0xff);
  dst[6] = (uint8_t) ((body >> 16) & 0xff);
  dst[7] = (uint8_t) ((body >> 24) & 0xff);
  return n;
}

/* ---- EXIF ------------------------------------------------------------- */

int zpx_int_exif_orientation(const uint8_t *t, size_t len) {
  int le;
  uint32_t ifd, count;
  if (len < 8) return 0;
  if (memcmp(t, "II*\0", 4) == 0) le = 1;
  else if (memcmp(t, "MM\0*", 4) == 0) le = 0;
  else return 0;
  ifd = le ? le32(t + 4) : be32(t + 4);
  /* IFD0 must start after the header and leave room for its count. */
  if (ifd < 8 || (size_t) ifd > len - 2) return 0;
  count = le ? le16(t + ifd) : be16(t + ifd);
  if ((size_t) count > (len - ifd - 2) / 12) return 0;
  for (uint32_t i = 0; i < count; i++) {
    const uint8_t *e = t + ifd + 2 + 12 * (size_t) i;
    uint32_t tag = le ? le16(e) : be16(e);
    uint32_t type = le ? le16(e + 2) : be16(e + 2);
    uint32_t n = le ? le32(e + 4) : be32(e + 4);
    if (tag == 0x0112) {
      uint32_t v;
      if (type != 3 || n != 1) return 0;
      v = le ? le16(e + 8) : be16(e + 8);
      return v >= 1 && v <= 8 ? (int) v : 0;
    }
  }
  return 0;
}

/* ---- entry points ------------------------------------------------------ */

zpx_status zpx_int_scan(const uint8_t *buf, size_t len,
                        const zpx_limits *limits, zpx_meta *m,
                        const char **detail) {
  zpx_status s;
  memset(m, 0, sizeof *m);
  m->density_unit = -1;
  m->srgb = -1;
  m->format = zpx_sniff(buf, len);
  switch (m->format) {
  case ZPX_FMT_PNG: s = scan_png(buf, len, m, detail); break;
  case ZPX_FMT_JPEG: {
    /* Collecting the ICC segments checks their numbering too: a gap, a
     * repeat or a count of zero is a decode error. */
    icc_segments segs;
    s = walk_jpeg(buf, len, m, &segs, detail);
    break;
  }
  case ZPX_FMT_WEBP: s = scan_webp(buf, len, m, detail); break;
  case ZPX_FMT_QOI:
    if (len < 14) return fail(detail, "QOI header is truncated");
    m->width = be32(buf + 4);
    m->height = be32(buf + 8);
    if (buf[12] != 3 && buf[12] != 4)
      return fail(detail, "QOI channel count is invalid");
    m->channels = buf[12];
    m->alpha = buf[12] == 4;
    m->colour_type = m->alpha ? ZPX_CT_RGBA : ZPX_CT_RGB;
    m->bits = 8;
    m->qoi_linear = buf[13] == 1;
    s = ZPX_OK;
    break;
  default:
    *detail = "not a PNG, JPEG, WebP or QOI signature";
    return ZPX_ERR_FORMAT;
  }
  if (s != ZPX_OK) return s;
  if (m->exif_len > 0)
    m->orientation =
        zpx_int_exif_orientation(buf + m->exif_off, m->exif_len);
  return metadata_cap(m, limits, detail);
}

zpx_status zpx_int_icc(const uint8_t *buf, size_t len, const zpx_meta *m,
                       const zpx_limits *limits, uint8_t *dst, size_t *out_len,
                       const char **detail) {
  if (m->icc_len == 0) {
    *out_len = 0;
    return ZPX_OK;
  }
  if (m->icc_segments > 0) {
    icc_segments local;
    size_t total = 0;
    zpx_status s = walk_jpeg(buf, len, NULL, &local, detail);
    if (s != ZPX_OK) return s;
    for (int i = 1; i <= local.count; i++) {
      if (dst) memcpy(dst + total, buf + local.off[i], local.len[i]);
      total += local.len[i];
    }
    *out_len = total;
    return ZPX_OK;
  }
  if (!m->icc_compressed) {
    if (dst) memcpy(dst, buf + m->icc_off, m->icc_len);
    *out_len = m->icc_len;
    return ZPX_OK;
  }
  /* PNG iCCP: inflate with max_metadata as the output bound, never into a
   * buffer sized by a claim (design §6.5). Without dst, count only. */
  {
    z_stream z;
    uint8_t scratch[16384];
    uint64_t cap = limits->max_metadata, total = 0;
    int r;
    memset(&z, 0, sizeof z);
    if (inflateInit(&z) != Z_OK) return ZPX_ERR_MEMORY;
    z.next_in = (Bytef *) (buf + m->icc_off);
    z.avail_in = (uInt) m->icc_len;
    do {
      size_t room = dst ? (size_t) (*out_len - total) : sizeof scratch;
      if (dst && room == 0) {
        r = Z_BUF_ERROR;
        break;
      }
      if (room > sizeof scratch && !dst) room = sizeof scratch;
      if (room > 0x40000000u) room = 0x40000000u;
      z.next_out = dst ? dst + total : scratch;
      z.avail_out = (uInt) room;
      r = inflate(&z, Z_NO_FLUSH);
      total += room - z.avail_out;
      if (total > cap) {
        inflateEnd(&z);
        *detail = "the ICC profile inflates past max_metadata";
        return ZPX_ERR_LIMIT;
      }
    } while (r == Z_OK);
    inflateEnd(&z);
    if (r != Z_STREAM_END) {
      *detail = "PNG iCCP profile does not inflate";
      return ZPX_ERR_DECODE;
    }
    *out_len = (size_t) total;
    return ZPX_OK;
  }
}
