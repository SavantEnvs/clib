/*
 * manifest_probe — a dynamically-linked known-answer driver for clib's package
 * manifest parser (src/common/clib-package.c clib_package_new()). Used ONLY by
 * mayhem/test.sh as a behavioral oracle: it links the real project code
 * (NORMAL flags), parses argv[2] (a manifest JSON string) and prints the
 * requested field. test.sh asserts the EXACT value, so neutering the parser
 * (or the sabotage shim) prints nothing/`(null)` and the assertion FAILS.
 *
 *   usage: manifest_probe <name|version|repo> <json>
 */
#include <stdio.h>
#include <string.h>

#include "clib-package.h"

int main(int argc, char *argv[])
{
  if (argc < 3) { fprintf(stderr, "usage: %s <name|version|repo> <json>\n", argv[0]); return 2; }

  clib_package_t *pkg = clib_package_new(argv[2], 0);
  if (!pkg) { printf("(parse-error)\n"); return 0; }

  const char *what = argv[1];
  const char *v = NULL;
  if      (0 == strcmp(what, "name"))    v = pkg->name;
  else if (0 == strcmp(what, "version")) v = pkg->version;
  else if (0 == strcmp(what, "repo"))    v = pkg->repo;
  else { fprintf(stderr, "unknown field: %s\n", what); clib_package_free(pkg); return 2; }

  printf("%s\n", v ? v : "(null)");
  clib_package_free(pkg);
  return 0;
}
