/*
 * parse_repo_probe — a tiny dynamically-linked known-answer driver for clib's
 * repo-slug parser (deps/parse-repo). Used ONLY by mayhem/test.sh as the
 * behavioral oracle: it links the real project code (parse-repo.c + substr.c +
 * strdup.c, NORMAL flags), parses argv[2] (a slug), and prints the requested
 * field. test.sh asserts the EXACT value, so neutering the parser to a no-op
 * (or the verify-repo sabotage shim that _exit(0)s the probe) prints nothing
 * and every assertion FAILS.
 *
 *   usage: parse_repo_probe <owner|name|version> <slug>
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "parse-repo.h"

int main(int argc, char *argv[])
{
  if (argc < 3) { fprintf(stderr, "usage: %s <owner|name|version> <slug>\n", argv[0]); return 2; }

  const char *what = argv[1];
  const char *slug = argv[2];
  char *res = NULL;

  if (0 == strcmp(what, "owner"))        res = parse_repo_owner(slug, "clibs");
  else if (0 == strcmp(what, "name"))    res = parse_repo_name(slug);
  else if (0 == strcmp(what, "version")) res = parse_repo_version(slug, "master");
  else { fprintf(stderr, "unknown field: %s\n", what); return 2; }

  printf("%s\n", res ? res : "(null)");
  free(res);
  return 0;
}
