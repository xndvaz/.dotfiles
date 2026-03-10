#!/usr/bin/env bash
set -euo pipefail

# Smoke tests for doctor.sh argument semantics.
# Focus:
# - help and unknown-flag handling
# - non-interactive and dry-run execution paths
# - dry-run mode must not mutate HOME dotfiles links

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DOCTOR_SCRIPT="$REPO_ROOT/scripts/doctor.sh"
BASH_BIN="$(command -v bash)"

if [[ -z "${BASH_BIN:-}" ]]; then
  echo "Error: bash not found in PATH." >&2
  exit 1
fi

if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
  echo "Error: test runner requires Bash 4+." >&2
  exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-flags.XXXXXX")"
PASS_COUNT=0
FAIL_COUNT=0
CASE_ID=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

run_case() {
  local should_fail="$1"
  local label="$2"
  shift 2

  CASE_ID=$((CASE_ID + 1))

  local case_home="$TMP_ROOT/home-$CASE_ID"
  local output_file="$TMP_ROOT/case-$CASE_ID.log"
  local rc=0

  mkdir -p "$case_home"

  if HOME="$case_home" "$BASH_BIN" "$DOCTOR_SCRIPT" "$@" >"$output_file" 2>&1; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$should_fail" -eq 0 && "$rc" -eq 0 ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "PASS: $label"
    return 0
  fi

  if [[ "$should_fail" -eq 1 && "$rc" -ne 0 ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "PASS: $label (failed as expected)"
    return 0
  fi

  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $label (exit code $rc)"
  echo "--- output ---"
  sed -n '1,200p' "$output_file"
  echo "--------------"
}

assert_dry_run_no_mutation() {
  local case_home="$TMP_ROOT/home-dry-run-audit"
  local output_file="$TMP_ROOT/case-dry-run-audit.log"
  local rc=0

  mkdir -p "$case_home"
  if HOME="$case_home" "$BASH_BIN" "$DOCTOR_SCRIPT" --fix --dry-run --non-interactive >"$output_file" 2>&1; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$rc" -ne 0 ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: dry-run mutation audit command failed (exit code $rc)"
    sed -n '1,200p' "$output_file"
    return
  fi

  if [[ -e "$case_home/.zshrc" ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: dry-run created $case_home/.zshrc"
    return
  fi

  if [[ -e "$case_home/Library/Application Support/Code/User/settings.json" ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: dry-run created VS Code settings symlink"
    return
  fi

  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: dry-run did not mutate HOME"
}

run_case 0 "help output" --help
run_case 1 "unknown argument rejected" --unknown-flag
run_case 0 "non-interactive run" --non-interactive
run_case 0 "fix dry-run non-interactive run" --fix --dry-run --non-interactive

assert_dry_run_no_mutation

echo ""
echo "doctor.sh smoke tests: $PASS_COUNT passed, $FAIL_COUNT failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
