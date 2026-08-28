/*
 * libFuzzer harness for clib's package-manifest parser — the SAME code path as
 * upstream's OSS-Fuzz target test/fuzzing/fuzz_manifest.c, but WITHOUT the file
 * I/O. Upstream's harness writes the fuzzer bytes to "libfuzzer.json" on disk
 * and calls clib_package_load_from_manifest(), which just fopen/reads the file
 * and hands the text to clib_package_new(). Under Mayhem the image is mounted
 * read-only and the target runs from its own cwd, so that on-disk round-trip is
 * both forbidden (§3, no file I/O) and fragile. We call clib_package_new()
 * directly on a NUL-terminated copy of the bytes — identical manifest-parsing
 * code (parson JSON parse + parse-repo/field extraction), byte-in, no files.
 */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "clib-package.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  char *json = (char *) malloc(size + 1);
  if (!json) return 0;
  if (size) memcpy(json, data, size);
  json[size] = '\0';

  clib_package_t *pkg = clib_package_new(json, 0);
  if (pkg) clib_package_free(pkg);

  free(json);
  return 0;
}
