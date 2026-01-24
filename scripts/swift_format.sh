#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

xcrun swift-format format \
  --in-place \
  --recursive \
  --parallel \
  --configuration .swift-format \
  Ordinatio \
  OrdinatioCore/Package.swift \
  OrdinatioCore/Sources \
  OrdinatioCore/Tests \
  OrdinatioTests \
  OrdinatioUITests

