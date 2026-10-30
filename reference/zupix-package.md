# zupix: Read and Write 'PNG', 'JPEG', 'WebP' and 'QOI' Images

Decodes and encodes 'PNG', 'JPEG', 'WebP' and 'QOI' images with every
codec compiled into the package, so installing it needs no system image
library. Images decode to a native raster or to an integer or double
array at 8 or 16 bits, and encode from the same shapes. Headers and
metadata, including 'ICC' profiles and 'EXIF' orientation, are read
without decoding pixels, and every size an image declares is checked
before memory is allocated. The codecs are also available to other
packages' C code through a registered function table.

## See also

Useful links:

- <https://pedrobtz.github.io/zupix/>

- <https://github.com/pedrobtz/zupix>

- Report bugs at <https://github.com/pedrobtz/zupix/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- The Wuffs Authors (bundled Wuffs library) \[copyright holder\]

- Thomas G. Lane (bundled libjpeg-turbo, from the Independent JPEG
  Group's software) \[contributor, copyright holder\]

- Guido Vollbeding (bundled libjpeg-turbo, from the Independent JPEG
  Group's software) \[contributor, copyright holder\]

- D. R. Commander (bundled libjpeg-turbo) \[contributor, copyright
  holder\]

- Google Inc. (bundled libwebp, and parts of bundled libjpeg-turbo)
  \[copyright holder\]

- Dominic Szablewski (bundled qoi.h) \[contributor, copyright holder\]

- Other contributors to libjpeg-turbo (see inst/COPYRIGHTS) \[copyright
  holder\]
