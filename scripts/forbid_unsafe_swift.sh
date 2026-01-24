#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

declare -a NEEDLES=(
  '@unchecked Sendable'
  'nonisolated(unsafe)'
  'DispatchQueue.main.async'
  'fatalError('
)

filter_matches() {
  if command -v rg >/dev/null 2>&1; then
    rg -v 'SAFETY:|JUSTIFIED:' | rg -v 'DispatchQueue\\.main\\.asyncAfter'
  else
    grep -vE 'SAFETY:|JUSTIFIED:' | grep -vF 'DispatchQueue.main.asyncAfter'
  fi
}

find_matches() {
  local needle="$1"
  if command -v rg >/dev/null 2>&1; then
    rg -n --fixed-strings "$needle" --glob '*.swift' --glob '!**/.build/**' --glob '!**/DerivedData/**' .
    return
  fi

  find . -type f -name '*.swift' -not -path '*/.build/*' -not -path '*/DerivedData/*' -print0 \
    | xargs -0 grep -nH -F "$needle" || true
}

for needle in "${NEEDLES[@]}"; do
  matches="$(find_matches "$needle" | filter_matches || true)"

  if [[ -n "$matches" ]]; then
    echo "Banned Swift escape found (missing SAFETY:/JUSTIFIED:): $needle" >&2
    echo "$matches" >&2
    exit 1
  fi
done
