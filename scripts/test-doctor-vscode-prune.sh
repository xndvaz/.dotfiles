#!/usr/bin/env bash
set -euo pipefail

# Smoke tests for doctor VS Code extension pruning behavior.
# Focus:
# - --fix --dry-run reports extension removals without uninstalling
# - --fix performs uninstall for extensions outside baseline

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DOCTOR_SCRIPT="$REPO_ROOT/scripts/doctor.sh"
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

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-vscode-prune.XXXXXX")"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

write_code_mock() {
  local path="$1"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--list-extensions" ]]; then
  printf '%s\n' "${MOCK_CODE_LIST:-}"
  exit 0
fi

if [[ "${1:-}" == "--uninstall-extension" ]]; then
  if [[ -z "${MOCK_UNINSTALL_LOG:-}" ]]; then
    exit 2
  fi
  printf '%s\n' "${2:-}" >>"$MOCK_UNINSTALL_LOG"
  exit 0
fi

if [[ "${1:-}" == "--version" ]]; then
  echo "1.0.0"
  exit 0
fi

exit 0
EOF
  chmod +x "$path"
}

run_dry_run_case() {
  local case_root="$TMP_ROOT/dry-run"
  local case_home="$case_root/home"
  local mock_bin="$case_root/mock-bin"
  local output_file="$case_root/output.log"
  local uninstall_log="$case_root/uninstall.log"
  local rc=0

  mkdir -p "$case_home" "$mock_bin"
  write_code_mock "$mock_bin/code"
  : >"$uninstall_log"

  if HOME="$case_home" \
    PATH="$mock_bin:$ORIGINAL_PATH" \
    MOCK_UNINSTALL_LOG="$uninstall_log" \
    MOCK_CODE_LIST=$'esbenp.prettier-vscode\nacme.extra-ext' \
    "$BASH_BIN" "$DOCTOR_SCRIPT" --fix --dry-run --non-interactive >"$output_file" 2>&1; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL: doctor --fix --dry-run returned $rc"
    sed -n '1,220p' "$output_file"
    return 1
  fi

  if ! grep -q 'Would uninstall VS Code extension: acme.extra-ext' "$output_file"; then
    echo "FAIL: doctor dry-run did not report planned VS Code extension removal"
    sed -n '1,220p' "$output_file"
    return 1
  fi

  if [[ -s "$uninstall_log" ]]; then
    echo "FAIL: doctor dry-run attempted real extension uninstall"
    cat "$uninstall_log"
    return 1
  fi

  echo "PASS: doctor --fix --dry-run reports prune without uninstalling"
}

run_fix_case() {
  local case_root="$TMP_ROOT/fix"
  local case_home="$case_root/home"
  local mock_bin="$case_root/mock-bin"
  local output_file="$case_root/output.log"
  local uninstall_log="$case_root/uninstall.log"
  local rc=0

  mkdir -p "$case_home" "$mock_bin"
  write_code_mock "$mock_bin/code"
  : >"$uninstall_log"

  if HOME="$case_home" \
    PATH="$mock_bin:$ORIGINAL_PATH" \
    MOCK_UNINSTALL_LOG="$uninstall_log" \
    MOCK_CODE_LIST=$'esbenp.prettier-vscode\nacme.extra-ext' \
    "$BASH_BIN" "$DOCTOR_SCRIPT" --fix --non-interactive >"$output_file" 2>&1; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$rc" -ne 0 ]]; then
    echo "FAIL: doctor --fix returned $rc"
    sed -n '1,260p' "$output_file"
    return 1
  fi

  if ! grep -Fxq 'acme.extra-ext' "$uninstall_log"; then
    echo "FAIL: doctor --fix did not uninstall extension outside baseline"
    sed -n '1,260p' "$output_file"
    echo "--- uninstall log ---"
    cat "$uninstall_log"
    echo "---------------------"
    return 1
  fi

  echo "PASS: doctor --fix uninstalls VS Code extensions outside baseline"
}

if run_dry_run_case; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

if run_fix_case; then
  PASS_COUNT=$((PASS_COUNT + 1))
else
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "doctor VS Code prune tests: $PASS_COUNT passed, $FAIL_COUNT failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
