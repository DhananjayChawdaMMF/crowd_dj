#!/usr/bin/env bash
# Regenerates assets/fonts/InterTight-{400,600,700,800}.ttf from the variable font.
# Needs Python 3 with fonttools:  python3 -m venv .venv && .venv/bin/pip install fonttools brotli
# Usage: PY=.venv/bin tool/subset_fonts.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${PY:-}"; [ -n "$PY" ] && PY="$PY/"
SRC=tool/fonts/InterTight-variable.ttf
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
UNICODES="U+0020-007E,U+00A0-00FF,U+0131,U+0152-0153,U+02C6,U+02DA,U+02DC,U+2013-2014,U+2018-201A,U+201C-201E,U+2020-2022,U+2026,U+2030,U+2039-203A,U+20AC,U+2122,U+2190-2193,U+2212,U+00B7"
for w in 400 600 700 800; do
  "${PY}fonttools" varLib.instancer "$SRC" "wght=$w" -o "$TMP/i-$w.ttf" -q
  "${PY}pyftsubset" "$TMP/i-$w.ttf" --unicodes="$UNICODES" \
    --layout-features='kern,liga,calt,ccmp,locl,mark,mkmk' \
    --output-file="assets/fonts/InterTight-$w.ttf"
done
ls -la assets/fonts
