/* Deliberately bad: tools/check-symbols --canary must reject the shared
 * object built from this file. */
#include <stdio.h>
#include <stdlib.h>

void R_init_zupix(void *dll) { (void)dll; }

int zupix_canary_stray_export(int x) {
  if (x < 0) {
    fprintf(stderr, "negative\n");
    exit(1);
  }
  return x;
}
