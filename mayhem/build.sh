#!/usr/bin/env bash
#
# mayhem/build.sh — build clib's bundled-parser fuzz harnesses + behavioral oracle probes.
#
# Fuzz targets:
#   fuzz_parse_repo — in-process libFuzzer harness over deps/parse-repo's
#                     parse_repo_owner/name/version() (clib's package-slug parser,
#                     backed by the bundled substr()/strdup() helpers).
#   fuzz_parson     — in-process libFuzzer harness over deps/parson's
#                     json_parse_string() (clib's bundled JSON parser; the code
#                     that reads every clib.json/package.json).
#   fuzz_manifest   — in-process libFuzzer harness over src/common/clib-package.c
#                     clib_package_new() (the whole manifest parser: JSON parse +
#                     field/repo extraction). SAME code path as upstream's
#                     OSS-Fuzz target test/fuzzing/fuzz_manifest.c, minus its
#                     file I/O. Links all deps/*/*.c + src/common/*.c + libcurl.
#
# The PROJECT code (parse-repo.c/substr.c/strdup.c, parson.c) is compiled with
# $SANITIZER_FLAGS AND -fsanitize=fuzzer-no-link UNCONDITIONALLY so the fuzzed
# code carries SanCov instrumentation (otherwise 0 edges in Mayhem), plus
# $DEBUG_FLAGS for DWARF<4 (the base's SANITIZER_FLAGS ends in plain -g=DWARF5,
# so -gdwarf-3 must come AFTER it).
#
# The oracle probes are a SEPARATE clean build with NORMAL flags (no sanitizer,
# no -gdwarf-3), dynamically linked so mayhem/test.sh's LD_PRELOAD sabotage
# check bites.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"

SRC="${SRC:-/mayhem}"
cd "$SRC"

DEPS="$SRC/deps"
HDIR="$SRC/mayhem/harnesses"
PDIR="$SRC/mayhem/probes"
BUILD="$SRC/mayhem-build"
mkdir -p "$BUILD"

# Include roots so each dep resolves both its "<dep>/<hdr>.h" and local "<hdr>.h".
INC="-I$DEPS -I$DEPS/parse-repo -I$DEPS/substr -I$DEPS/strdup -I$DEPS/parson"

echo "== build.sh: SANITIZER_FLAGS=[$SANITIZER_FLAGS] DEBUG_FLAGS=[$DEBUG_FLAGS] =="

# Standalone run-once driver (a C file) — compiled ONCE, linked per harness.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -x c -c "$STANDALONE_FUZZ_MAIN" \
    -o "$BUILD/standalone_main.o"

# ===========================================================================
# Target 1: fuzz_parse_repo
# ===========================================================================
# Instrument the project sources (sanitizer + fuzzer-no-link ALWAYS).
for u in parse-repo/parse-repo substr/substr strdup/strdup; do
  base=$(basename "$u")
  $CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link \
      $INC -c "$DEPS/$u.c" -o "$BUILD/pr_$base.san.o"
done
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link \
    $INC -c "$HDIR/fuzz_parse_repo.c" -o "$BUILD/fuzz_parse_repo.o"

PR_OBJS="$BUILD/pr_parse-repo.san.o $BUILD/pr_substr.san.o $BUILD/pr_strdup.san.o"

$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    "$BUILD/fuzz_parse_repo.o" $PR_OBJS -o /mayhem/fuzz_parse_repo

$CC $SANITIZER_FLAGS $DEBUG_FLAGS \
    "$BUILD/standalone_main.o" "$BUILD/fuzz_parse_repo.o" $PR_OBJS \
    -o /mayhem/fuzz_parse_repo-standalone

# ===========================================================================
# Target 2: fuzz_parson  (parson.c needs libm for math.h)
# ===========================================================================
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link \
    $INC -c "$DEPS/parson/parson.c" -o "$BUILD/parson.san.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link \
    $INC -c "$HDIR/fuzz_parson.c" -o "$BUILD/fuzz_parson.o"

$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    "$BUILD/fuzz_parson.o" "$BUILD/parson.san.o" -lm -o /mayhem/fuzz_parson

$CC $SANITIZER_FLAGS $DEBUG_FLAGS \
    "$BUILD/standalone_main.o" "$BUILD/fuzz_parson.o" "$BUILD/parson.san.o" -lm \
    -o /mayhem/fuzz_parson-standalone

# ===========================================================================
# Oracle probes — CLEAN builds (NORMAL flags; NO sanitizer, NO -gdwarf-3),
# dynamically linked so mayhem/test.sh's LD_PRELOAD sabotage shim can reach them.
# ===========================================================================
$CC -O2 -std=gnu99 $INC \
    "$PDIR/parse_repo_probe.c" \
    "$DEPS/parse-repo/parse-repo.c" "$DEPS/substr/substr.c" "$DEPS/strdup/strdup.c" \
    -o /mayhem/parse_repo_probe

$CC -O2 -std=gnu99 $INC \
    "$PDIR/parson_probe.c" "$DEPS/parson/parson.c" -lm \
    -o /mayhem/parson_probe

# ===========================================================================
# Target 3: fuzz_manifest — clib's package-manifest parser (clib_package_new).
#   Mirror upstream's Makefile: compile every bundled dep (deps/*/*.c) plus the
#   src/common/*.c library, link libcurl + pthread + libm. libcurl dev is baked
#   into the image by the Dockerfile (root apt layer). Sanitizer +
#   fuzzer-no-link on every object so the WHOLE parser carries SanCov edges.
# ===========================================================================
CURL_CFLAGS="$(curl-config --cflags)"
CURL_LIBS="$(curl-config --libs)"
MAN_CF="-std=c99 -I$DEPS -I$SRC/src/common -Wno-unused-function -U__STRICT_ANSI__ $CURL_CFLAGS"
MANBUILD="$BUILD/manifest"
mkdir -p "$MANBUILD"

MAN_OBJS=""
for f in "$SRC"/deps/*/*.c "$SRC"/src/common/*.c; do
  o="$MANBUILD/$(echo "$f" | tr '/.' '__').o"
  $CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link $MAN_CF -c "$f" -o "$o"
  MAN_OBJS="$MAN_OBJS $o"
done

$CC $SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link $MAN_CF \
    -c "$HDIR/fuzz_manifest.c" -o "$MANBUILD/fuzz_manifest.o"

$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    "$MANBUILD/fuzz_manifest.o" $MAN_OBJS $CURL_LIBS -lpthread -lm \
    -o /mayhem/fuzz_manifest

$CC $SANITIZER_FLAGS $DEBUG_FLAGS \
    "$BUILD/standalone_main.o" "$MANBUILD/fuzz_manifest.o" $MAN_OBJS $CURL_LIBS -lpthread -lm \
    -o /mayhem/fuzz_manifest-standalone

# Oracle probe for the manifest parser (clean NORMAL-flag build).
$CC -O2 $MAN_CF "$PDIR/manifest_probe.c" \
    $(for f in "$SRC"/deps/*/*.c "$SRC"/src/common/*.c; do echo "$f"; done) \
    $CURL_LIBS -lpthread -lm -o /mayhem/manifest_probe

for p in /mayhem/parse_repo_probe /mayhem/parson_probe /mayhem/manifest_probe; do
  if ! file "$p" | grep -q 'dynamically linked'; then
    echo "FATAL: $p is not dynamically linked — oracle would be un-neuterable" >&2
    file "$p" >&2
    exit 1
  fi
done

echo "== build.sh: OK =="
ls -l /mayhem/fuzz_parse_repo /mayhem/fuzz_parse_repo-standalone \
      /mayhem/fuzz_parson /mayhem/fuzz_parson-standalone \
      /mayhem/fuzz_manifest /mayhem/fuzz_manifest-standalone \
      /mayhem/parse_repo_probe /mayhem/parson_probe /mayhem/manifest_probe
