/*
 * parson_probe — a tiny dynamically-linked known-answer driver for clib's
 * bundled JSON parser (deps/parson). Used ONLY by mayhem/test.sh as the
 * behavioral oracle: it links the real project code (parson.c, NORMAL flags),
 * parses argv[1] (a JSON document) and prints the string value at the dotted
 * key argv[2]. test.sh asserts the EXACT parsed value, so neutering the parser
 * (or the sabotage shim) prints nothing/`(null)` and the assertion FAILS.
 *
 *   usage: parson_probe <json> <dotted-key>
 */
#include <stdio.h>
#include <stdlib.h>

#include "parson.h"

int main(int argc, char *argv[])
{
  if (argc < 3) { fprintf(stderr, "usage: %s <json> <dotted-key>\n", argv[0]); return 2; }

  JSON_Value *v = json_parse_string(argv[1]);
  if (!v) { printf("(parse-error)\n"); return 0; }

  JSON_Object *obj = json_value_get_object(v);
  const char *s = obj ? json_object_dotget_string(obj, argv[2]) : NULL;

  printf("%s\n", s ? s : "(null)");
  json_value_free(v);
  return 0;
}
