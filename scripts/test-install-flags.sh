#!/usr/bin/env bash
set -euo pipefail

# Smoke tests for install.sh argument semantics.
# Focus:
# - valid non-interactive combinations
# - invalid/conflicting flag combinations
# - dry-run mode never mutates HOME

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$REPO_ROOT/scripts/install.sh"
BASH_BIN="$(command -v bash)"

if [[ -z "${BASH_BIN:-}" ]]; then
  echo "Error: bash not found in PATH." >&2
  exit 1
fi

if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
  echo "Error: test runner requires Bash 4+." >&2
  exit 1
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-flags.XXXXXX")"
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

  if HOME="$case_home" "$BASH_BIN" "$INSTALL_SCRIPT" "$@" >"$output_file" 2>&1; then
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
  if HOME="$case_home" "$BASH_BIN" "$INSTALL_SCRIPT" \
    --dry-run \
    --non-interactive \
    --configure-signing=no \
    --configure-identity=no >"$output_file" 2>&1; then
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
run_case 0 "non-interactive dry-run skip optional git steps" \
  --dry-run --non-interactive --configure-signing=no --configure-identity=no
run_case 0 "non-interactive dry-run explicit identity values" \
  --dry-run --non-interactive --configure-signing=no --configure-identity=yes \
  --git-name "CI Test" --git-email "ci@example.com"

run_case 1 "invalid configure-signing value" --configure-signing=maybe
run_case 1 "invalid configure-identity value" --configure-identity=maybe
run_case 1 "signing key conflicts with explicit signing=no" \
  --configure-signing=no --signing-key "ssh-ed25519 AAAATESTKEY"
run_case 1 "git-name conflicts with explicit identity=no" \
  --configure-identity=no --git-name "Only Name"
run_case 1 "git-email conflicts with explicit identity=no" \
  --configure-identity=no --git-email "only@example.com"
run_case 1 "invalid signing key format" --signing-key "invalid-key-format"
run_case 1 "identity required but email missing" \
  --dry-run --non-interactive --configure-identity=yes --git-name "Only Name"
run_case 1 "unknown argument rejected" --unknown-flag

assert_dry_run_no_mutation

echo ""
echo "install.sh smoke tests: $PASS_COUNT passed, $FAIL_COUNT failed"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
