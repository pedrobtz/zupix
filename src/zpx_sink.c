#include <stdlib.h>
#include <string.h>

#include "zpx_core.h"

/* Appends to a zpx_buffer, growing it geometrically. */
int zpx_int_buffer_write(void *closure, const uint8_t *data, size_t len) {
  zpx_buffer *b = (zpx_buffer *) closure;
  /* Untested, both failures: an encoded image never nears SIZE_MAX, and
   * realloc() fails only when out of memory. */
  if (len > SIZE_MAX - b->len) return 1;
  if (b->len + len > b->cap) {
    size_t cap = b->cap ? b->cap : 65536;
    uint8_t *p;
    while (cap < b->len + len) {
      if (cap > SIZE_MAX / 2) {
        cap = b->len + len;
        break;
      }
      cap *= 2;
    }
    p = (uint8_t *) realloc(b->data, cap);
    if (p == NULL) return 1;
    b->data = p;
    b->cap = cap;
  }
  memcpy(b->data + b->len, data, len);
  b->len += len;
  return 0;
}
