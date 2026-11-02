#!/usr/bin/env bash
# make-release.sh — build dist/mac-assurance-<VERSION>.tar.gz + .sha256
# Excludes per-machine/sensitive state: baseline.txt, config.local.sh, reports, dist, .git
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
V="$(cat "$HERE/VERSION")"; OUT="${DIST_DIR:-$HERE/dist}"; mkdir -p "$OUT"
STAGE="$(mktemp -d)/mac-assurance-$V"; mkdir -p "$STAGE"
(cd "$HERE" && tar --exclude='./dist' --exclude='./.git' --exclude='./reports' \
  --exclude='./baseline.txt' --exclude='./config.local.sh' --exclude='./fixes-pending.txt' \
  --exclude='__pycache__' --exclude='.DS_Store' -cf - .) | (cd "$STAGE" && tar -xf -)
tar -czf "$OUT/mac-assurance-$V.tar.gz" -C "$(dirname "$STAGE")" "mac-assurance-$V"
(cd "$OUT" && shasum -a 256 "mac-assurance-$V.tar.gz" > "mac-assurance-$V.tar.gz.sha256")
rm -rf "$(dirname "$STAGE")"
echo "Built $OUT/mac-assurance-$V.tar.gz"; cat "$OUT/mac-assurance-$V.tar.gz.sha256"
