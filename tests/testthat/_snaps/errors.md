# condition messages

    Code
      pix_read(1:3)
    Condition
      Error in `pix_read()`:
      ! `x` must be a file path, a raw vector or a connection.

---

    Code
      pix_read(png, as = "native", bits = 16L)
    Condition
      Error in `pix_read()`:
      ! `bits` must be NULL or 8 with as = "native", which is 8-bit.

---

    Code
      pix_read(png, as = "integer", channels = 1L)
    Condition
      Error in `pix_read()`:
      ! `channels` would remove channels the image has.

---

    Code
      pix_read(charToRaw("not an image"))
    Condition
      Error in `pix_read()`:
      ! The input is not a PNG, JPEG, WebP or QOI image.

---

    Code
      pix_read(png, format = "jpeg")
    Condition
      Error in `pix_read()`:
      ! `format` is "jpeg" but the input is PNG.

---

    Code
      pix_read(arithmetic)
    Condition
      Error in `pix_read()`:
      ! JPEG uses an unsupported feature: jpeg: unsupported arithmetic coding.

---

    Code
      pix_read(short_qoi)
    Condition
      Error in `pix_read()`:
      ! Can't decode QOI: QOI stream is truncated or lacks its end marker.

---

    Code
      pix_read(declared_png(1e+06, 1))
    Condition
      Error in `pix_read()`:
      ! PNG has a side of 1,000,000 pixels, more than `max_side` (65,535).

---

    Code
      pix_read(declared_png(30000, 30000))
    Condition
      Error in `pix_read()`:
      ! PNG has 900,000,000 pixels, more than `max_pixels` (100,000,000).

---

    Code
      pix_read(png, as = "double", limits = pix_limits(max_bytes = 100))
    Condition
      Error in `pix_read()`:
      ! Decoding this PNG needs 126 bytes, more than `max_bytes` (100). `as = "native"` needs the least memory.

---

    Code
      pix_icc(make_png(matrix(0L), 1L, 0L, chunks_before = list(icc)), limits = pix_limits(
        max_metadata = 1000))
    Condition
      Error in `pix_icc()`:
      ! PNG has 3,000 bytes of metadata, more than `max_metadata` (1,000).

---

    Code
      pix_write_webp(matrix(0L, 1L, 16384L))
    Condition
      Error in `pix_write_webp()`:
      ! Can't encode WebP: WebP holds at most 16,383 pixels a side.

---

    Code
      pix_read("no/such/file.png")
    Condition
      Error in `pix_read()`:
      ! no such file: no/such/file.png.

---

    Code
      zpx_raise_failure(failure(8L), "webp")
    Condition
      Error:
      ! Not enough memory for this WebP.

---

    Code
      zpx_raise_failure(failure(99L), NA)
    Condition
      Error:
      ! zupix internal error: a detail.

