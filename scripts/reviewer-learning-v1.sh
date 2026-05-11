#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: $(basename "$0") <review-output-file>" >&2
  exit 1
fi

review_file="$1"
if [[ ! -f "$review_file" ]]; then
  echo "review output file not found: $review_file" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCOPE_PATTERNS="$REPO_ROOT/.ai/reviewer-learning/in-scope-patterns.txt"

THRESHOLD=3

LEARNING_HOME="$HOME/.ai/reviewer-learning"
if ! mkdir -p "$LEARNING_HOME" 2>/dev/null; then
  LEARNING_HOME="${TMPDIR:-/tmp}/codex-reviewer-learning"
  mkdir -p "$LEARNING_HOME"
fi

STATE_FILE="$LEARNING_HOME/state.tsv"
NOTIFY_FILE="$LEARNING_HOME/notifications.log"
PROPOSAL_FILE="$LEARNING_HOME/proposals.log"

touch "$STATE_FILE" "$NOTIFY_FILE" "$PROPOSAL_FILE"

in_scope() {
  local text="$1"
  if [[ ! -f "$SCOPE_PATTERNS" ]]; then
    return 1
  fi
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    if printf '%s\n' "$text" | tr '[:upper:]' '[:lower:]' | grep -Fq "$(printf '%s' "$pattern" | tr '[:upper:]' '[:lower:]')"; then
      return 0
    fi
  done <"$SCOPE_PATTERNS"
  return 1
}

update_count() {
  local signature="$1"
  local severity="$2"
  local now count found tmp
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  count=0
  found=0

  tmp="$(mktemp)"
  while IFS=$'\t' read -r stored_sig stored_count stored_sev stored_updated; do
    [[ -n "$stored_sig" ]] || continue
    if [[ "$stored_sig" == "$signature" ]]; then
      count="$stored_count"
      count=$((count + 1))
      printf '%s\t%s\t%s\t%s\n' "$stored_sig" "$count" "$severity" "$now" >>"$tmp"
      found=1
    else
      printf '%s\t%s\t%s\t%s\n' "$stored_sig" "$stored_count" "$stored_sev" "$stored_updated" >>"$tmp"
    fi
  done <"$STATE_FILE"

  if [[ "$found" -eq 0 ]]; then
    count=1
    printf '%s\t%s\t%s\t%s\n' "$signature" "$count" "$severity" "$now" >>"$tmp"
  fi

  mv "$tmp" "$STATE_FILE"
  printf '%s\n' "$count"
}

while IFS= read -r line; do
  [[ "$line" =~ ^-\ \[([A-Z]+)\]\ (.+)$ ]] || continue
  severity="${BASH_REMATCH[1]}"
  detail="${BASH_REMATCH[2]}"

  if in_scope "$detail"; then
    count="$(update_count "$detail" "$severity")"
    if [[ "$count" -ge "$THRESHOLD" ]]; then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] IMPROVEMENT reviewer-learning-v1 pattern='${detail}' occurrences=${count} action='suggest stricter defaults (auto-notify only)'" >>"$NOTIFY_FILE"
      echo "[reviewer-learning-v1] improvement detected for recurring in-scope pattern: $detail"
    fi
  else
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] PROPOSAL out-of-scope detail='${detail}' status='approval-required'" >>"$PROPOSAL_FILE"
    echo "[reviewer-learning-v1] out-of-scope proposal queued for approval: $detail"
  fi
done <"$review_file"
