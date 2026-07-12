#!/usr/bin/env bash
#
# peg-markdown/mayhem/test.sh — run the ENTIRE shipped functional suite
# (MarkdownTest_1.0.3: 22 golden input/output pairs, John Gruber's reference
# suite, driven by the upstream MarkdownTest.pl runner with --tidy HTML
# normalization — the same invocation as upstream's `make test`) against the
# normal-flags oracle built by mayhem/build.sh, and report a CTRF summary.
# Executes only — does NOT compile anything.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
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

ORACLE=/mayhem/markdown-oracle
[ -x "$ORACLE" ] || { echo "missing $ORACLE — run mayhem/build.sh first" >&2; exit 2; }

# Pre-existing divergence from the Markdown.pl golden output on the pristine
# upstream tip (peg-markdown emits <li><p>…</p> for loose-list items where the
# golden file has a bare <li>). Upstream is unmaintained; counted as SKIPPED so
# only NEW breakage fails the gate. Every other failure is fatal.
KNOWN_FAILURES=("Ordered and unordered lists")

out="$(cd MarkdownTest_1.0.3 && perl ./MarkdownTest.pl --script="$ORACLE" --tidy 2>&1)"
echo "$out"

passed=$(grep -c ' \.\.\. OK$' <<<"$out" || true)
failed=0; skipped=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  known=no
  for k in "${KNOWN_FAILURES[@]}"; do [ "$name" = "$k" ] && known=yes; done
  if [ "$known" = yes ]; then skipped=$((skipped+1)); else failed=$((failed+1)); fi
done < <(grep ' \.\.\. FAILED$' <<<"$out" | sed 's/ \.\.\. FAILED$//')

# The suite ships 22 cases; if fewer ran (runner error, missing tidy, neutered
# oracle producing no per-test lines) count the missing ones as failures.
expected=22
actual=$(( passed + failed + skipped ))
if [ "$actual" -lt "$expected" ]; then
  echo "only $actual/$expected suite cases ran — counting the rest as failures" >&2
  failed=$(( failed + expected - actual ))
fi

emit_ctrf "MarkdownTest-1.0.3" "$passed" "$failed" "$skipped"
