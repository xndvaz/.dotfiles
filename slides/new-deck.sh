#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
  echo "Usage: $(basename "$0") <deck-name> [theme]" >&2
  exit 1
fi

deck_name="$1"
theme="${2:-default}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
template="$SCRIPT_DIR/template.html"
theme_path="$SCRIPT_DIR/themes/$theme/theme.css"
out="$SCRIPT_DIR/decks/${deck_name}.html"

if [[ ! -f "$template" ]]; then
  echo "Template not found: $template" >&2
  exit 1
fi
if [[ ! -f "$theme_path" ]]; then
  echo "Theme not found: $theme_path" >&2
  exit 1
fi

mkdir -p "$SCRIPT_DIR/decks"

sed \
  -e "s|__TITLE__|${deck_name}|g" \
  -e "s|__THEME__|${theme}|g" \
  "$template" >"$out"

echo "Created: $out"
