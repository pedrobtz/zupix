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
