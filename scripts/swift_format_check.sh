#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! git diff --quiet; then
  echo "Working tree is dirty; commit or stash changes before running formatting checks." >&2
  exit 2
fi

scripts/swift_format.sh

if ! git diff --quiet; then
  echo "swift-format produced changes. Run scripts/swift_format.sh and commit the result." >&2
  git --no-pager diff
  exit 1
fi

