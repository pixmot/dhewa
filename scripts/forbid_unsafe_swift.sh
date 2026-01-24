#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

declare -a PATTERNS=(
  '@unchecked[[:space:]]+Sendable'
  'nonisolated\\(unsafe\\)'
  'DispatchQueue\\.main\\.async(?!After)'
)

for pattern in "${PATTERNS[@]}"; do
  matches="$(
    rg -n --pcre2 "$pattern" \
      --glob '*.swift' \
      --glob '!**/.build/**' \
      --glob '!**/DerivedData/**' \
      . \
      | rg -v 'SAFETY:|JUSTIFIED:' || true
  )"

  if [[ -n "$matches" ]]; then
    echo "Banned Swift concurrency escape found (missing SAFETY:/JUSTIFIED:): $pattern" >&2
    echo "$matches" >&2
    exit 1
  fi
done

