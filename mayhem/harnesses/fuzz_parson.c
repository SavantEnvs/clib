/*
 * libFuzzer harness for clib's bundled JSON parser (deps/parson — a copy of
 * Krzysztof Gabis' parson). clib parses every package's clib.json/package.json
 * with this, so it is the project's headline parser and a rich fuzz surface.
 *
 * Byte-in only, no file I/O: the fuzzer bytes are copied into a NUL-terminated
 * string and handed to json_parse_string(). On success we also round-trip the
 * value through the serializer (exercising the writer paths) and free
 * everything. json_parse_file() is deliberately NOT used — no filesystem.
 */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "parson.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  char *str = (char *) malloc(size + 1);
  if (!str) return 0;
  if (size) memcpy(str, data, size);
  str[size] = '\0';

  JSON_Value *v = json_parse_string(str);
  if (v) {
    /* Exercise the serializer on well-formed input, then free. */
    char *out = json_serialize_to_string(v);
    if (out) json_free_serialized_string(out);
    json_value_free(v);
  }

  free(str);
  return 0;
}
