#!/usr/bin/env bash
set -euo pipefail

# Smoke tests for pre-commit reviewer gate semantics.
# Focus:
# - no findings -> allow
# - findings at any severity -> block
# - reviewer execution failure -> block (fail-closed)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
HOOK_SOURCE="$REPO_ROOT/scripts/hooks/pre-commit"
BASH_BIN="$(command -v bash)"
ORIGINAL_PATH="$PATH"

if [[ -z "${BASH_BIN:-}" ]]; then
  echo "Error: bash not found in PATH." >&2
  exit 1
fi

if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
  echo "Error: test runner requires Bash 4+." >&2
  exit 1
fi

if [[ ! -f "$HOOK_SOURCE" ]]; then
  echo "Error: hook source not found: $HOOK_SOURCE" >&2
  exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pre-commit.XXXXXX")"
PASS_COUNT=0
FAIL_COUNT=0
CASE_ID=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

write_shellcheck_stub() {
  local path="$1"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
  chmod +x "$path"
}

write_codex_stub() {
  local path="$1"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mode="${MOCK_CODEX_MODE:-pass}"
out_file=""

while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" && "$#" -ge 2 ]]; then
    out_file="$2"
    shift 2
    continue
  fi
  shift
done

if [[ -z "$out_file" ]]; then
  echo "missing --output-last-message path" >&2
  exit 2
fi

case "$mode" in
pass)
  cat >"$out_file" <<'OUT'
VERDICT: PASS
FINDINGS: 0
SEVERITY_COUNTS: CRITICAL=0 HIGH=0 MEDIUM=0 LOW=0
OUT
  ;;
fail_findings)
  cat >"$out_file" <<'OUT'
VERDICT: FAIL
FINDINGS: 1
SEVERITY_COUNTS: CRITICAL=0 HIGH=1 MEDIUM=0 LOW=0
- [HIGH] demo.sh:1 - mock reviewer finding
OUT
  ;;
exec_fail)
  exit 17
  ;;
*)
  cat >"$out_file" <<'OUT'
VERDICT: FAIL
FINDINGS: 1
SEVERITY_COUNTS: CRITICAL=0 HIGH=0 MEDIUM=1 LOW=0
- [MEDIUM] demo.sh:1 - unexpected test mode
OUT
  ;;
esac
EOF
  chmod +x "$path"
}

run_case() {
  local should_fail="$1"
  local label="$2"
  local codex_mode="$3"

  CASE_ID=$((CASE_ID + 1))

  local case_root="$TMP_ROOT/case-$CASE_ID"
  local repo_dir="$case_root/repo"
  local hooks_dir="$repo_dir/.githooks"
  local mock_bin="$case_root/mock-bin"
  local output_file="$case_root/output.log"
  local rc=0

  mkdir -p "$repo_dir" "$hooks_dir" "$mock_bin"

  cp "$HOOK_SOURCE" "$hooks_dir/pre-commit"
  chmod +x "$hooks_dir/pre-commit"

  write_shellcheck_stub "$mock_bin/shellcheck"
  if [[ "$codex_mode" != "missing" ]]; then
    write_codex_stub "$mock_bin/codex"
  fi

  (
    cd "$repo_dir"
    git init -q
    git config user.name "Test Runner"
    git config user.email "test@example.com"
    git config core.hooksPath "$hooks_dir"

    cat >demo.sh <<'EOF'
#!/usr/bin/env bash
echo "hello"
EOF
    chmod +x demo.sh
    git add demo.sh

    if PATH="$mock_bin:$ORIGINAL_PATH" MOCK_CODEX_MODE="$codex_mode" "$hooks_dir/pre-commit" >"$output_file" 2>&1; then
      rc=0
    else
      rc=$?
    fi

    if [[ "$should_fail" -eq 0 && "$rc" -eq 0 ]]; then
      echo "PASS: $label"
      exit 0
    fi

    if [[ "$should_fail" -eq 1 && "$rc" -ne 0 ]]; then
      echo "PASS: $label (failed as expected)"
      exit 0
    fi

    echo "FAIL: $label (exit code $rc)"
    echo "--- output ---"
    sed -n '1,200p' "$output_file"
    echo "--------------"
    exit 1
  )
}

if run_case 0 "no findings allows commit flow" "pass"; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if run_case 1 "findings block commit flow" "fail_findings"; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if run_case 1 "reviewer execution failure blocks commit flow" "exec_fail"; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "pre-commit smoke tests: $PASS_COUNT passed, $FAIL_COUNT failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
