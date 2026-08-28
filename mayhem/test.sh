#!/usr/bin/env bash
#
# mayhem/test.sh — behavioral oracle for clib's bundled parsers.
#
# Runs the CLEAN (non-sanitized), dynamically-linked probes built by
# mayhem/build.sh (linking the REAL deps/parse-repo + deps/parson sources) on
# fixed inputs and asserts the EXACT parsed values. These are known-answer
# tests: a PATCH that neuters a parser to a no-op (or the verify-repo sabotage
# shim that _exit(0)s the probe) produces empty/`(null)` output, so every
# assertion FAILS.
#
# Emits a CTRF summary + a compact `CTRF {...}` stdout marker; exits non-zero
# iff failed>0.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
SRC="${SRC:-/mayhem}"
cd "$SRC"

PR=/mayhem/parse_repo_probe
PJ=/mayhem/parson_probe
PM=/mayhem/manifest_probe

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Fail loudly if build.sh did not produce a probe (a build bug, not a skip).
for p in "$PR" "$PJ" "$PM"; do
  if [ ! -x "$p" ]; then
    echo "FATAL: $p missing/not executable — mayhem/build.sh did not build the oracle" >&2
    emit_ctrf "clib-parsers-kat" 0 1 0
    exit 1
  fi
done

passed=0
failed=0

assert() {
  local label="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then
    echo "PASS  $label -> '$got'"
    passed=$((passed + 1))
  else
    echo "FAIL  $label : want='$want' got='$got'"
    failed=$((failed + 1))
  fi
}

# --- parse-repo known-answer tests (deps/parse-repo semantics) --------------
assert "owner clibs/clib@1.0.0"   "clibs"  "$("$PR" owner   'clibs/clib@1.0.0' 2>/dev/null)"
assert "name  clibs/clib@1.0.0"   "clib"   "$("$PR" name    'clibs/clib@1.0.0' 2>/dev/null)"
assert "version clibs/clib@1.0.0" "1.0.0"  "$("$PR" version 'clibs/clib@1.0.0' 2>/dev/null)"
assert "version clib@* (star)"    "master" "$("$PR" version 'clibs/clib@*'     2>/dev/null)"
assert "owner fallback (no slug)" "clibs"  "$("$PR" owner   'clib'             2>/dev/null)"
assert "name foo/bar"             "bar"    "$("$PR" name    'foo/bar'          2>/dev/null)"

# --- parson JSON known-answer tests (deps/parson) ---------------------------
assert "parson name"    "clib"  "$("$PJ" '{"name":"clib","version":"1.0.0"}' name    2>/dev/null)"
assert "parson version" "1.0.0" "$("$PJ" '{"name":"clib","version":"1.0.0"}' version 2>/dev/null)"
assert "parson dotget"  "deep"  "$("$PJ" '{"a":{"b":"deep"}}'                a.b     2>/dev/null)"

# --- clib manifest known-answer tests (src/common/clib-package.c) -----------
assert "manifest name"    "clib"  "$("$PM" name    '{"name":"clib","version":"1.2.3","repo":"clibs/clib"}' 2>/dev/null)"
assert "manifest version" "1.2.3" "$("$PM" version '{"name":"clib","version":"1.2.3","repo":"clibs/clib"}' 2>/dev/null)"
assert "manifest repo"    "clibs/clib" "$("$PM" repo '{"name":"clib","version":"1.2.3","repo":"clibs/clib"}' 2>/dev/null)"

emit_ctrf "clib-parsers-kat" "$passed" "$failed" 0
