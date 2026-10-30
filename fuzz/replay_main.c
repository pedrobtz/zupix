/* A main() for the fuzz targets without libFuzzer: feeds each file named on
 * the command line (or each file in each directory named) to
 * LLVMFuzzerTestOneInput once. replay.sh builds it with ASan and UBSan to
 * replay the seeds and regressions anywhere, macOS included. */
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size);

static long run_file(const char *path) {
  FILE *f = fopen(path, "rb");
  long n;
  unsigned char *buf;
  if (f == NULL) return 0;
  fseek(f, 0, SEEK_END);
  n = ftell(f);
  fseek(f, 0, SEEK_SET);
  buf = (unsigned char *) malloc(n > 0 ? (size_t) n : 1);
  if (buf != NULL && fread(buf, 1, (size_t) n, f) == (size_t) n)
    LLVMFuzzerTestOneInput(buf, (size_t) n);
  free(buf);
  fclose(f);
  return 1;
}

int main(int argc, char **argv) {
  long count = 0;
  for (int i = 1; i < argc; i++) {
    struct stat st;
    if (stat(argv[i], &st) != 0) continue;
    if (S_ISDIR(st.st_mode)) {
      DIR *d = opendir(argv[i]);
      struct dirent *e;
      while (d != NULL && (e = readdir(d)) != NULL) {
        char p[4096];
        if (e->d_name[0] == '.') continue;
        snprintf(p, sizeof p, "%s/%s", argv[i], e->d_name);
        count += run_file(p);
      }
      if (d != NULL) closedir(d);
    } else {
      count += run_file(argv[i]);
    }
  }
  printf("replayed %ld inputs\n", count);
  return 0;
}
