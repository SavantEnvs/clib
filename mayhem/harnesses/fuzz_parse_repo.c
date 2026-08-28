/*
 * libFuzzer harness for clib's bundled repo-slug parser (deps/parse-repo).
 *
 * parse_repo_owner/name/version() are clib's package-slug parsers: they take a
 * slug like "clibs/clib@1.0.0" and pull out the owner ("clibs"), name ("clib")
 * and version ("1.0.0"). They lean on the bundled substr()/strdup() string
 * helpers (deps/substr, deps/strdup) — a small, self-contained string-parsing
 * surface with no file or global state.
 *
 * Byte-in only, no file I/O: the fuzzer bytes are copied into a NUL-terminated
 * buffer and handed to each parser as the slug. All returned heap strings are
 * freed. A fallback string is passed to exercise the fallback paths too.
 */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "parse-repo.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  /* NUL-terminate a copy: the parsers are C-string based (strlen/strchr). */
  char *slug = (char *) malloc(size + 1);
  if (!slug) return 0;
  if (size) memcpy(slug, data, size);
  slug[size] = '\0';

  char *owner = parse_repo_owner(slug, "clibs");
  char *name  = parse_repo_name(slug);
  char *ver   = parse_repo_version(slug, "master");

  free(owner);
  free(name);
  free(ver);
  free(slug);
  return 0;
}
