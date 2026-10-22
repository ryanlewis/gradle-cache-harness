#!/usr/bin/env bash
# Record Gradle User Home contents after restore, then report what the build added, by cache layer.
#   delta.sh record    after restore
#   delta.sh compare   after the build
# Each layer is listed as units (a dependency file, a transform or build-cache entry) with their sizes,
# which shows how much a finer-grained cache would need to upload.
set -uo pipefail

guh="${GRADLE_USER_HOME:-$HOME/.gradle}"
mkdir -p /tmp/delta /tmp/optrace

list() {
  cd "$guh" 2>/dev/null || return 0
  {
    find caches/modules-2/files-2.1 -type f -printf 'dependencies %s %p\n' 2>/dev/null
    for d in caches/transforms-* caches/*/transforms; do
      [ -d "$d" ] && find "$d" -mindepth 1 -maxdepth 1 -type d -exec du -sb {} + | awk '{print "transforms", $1, $2}'
    done
    find caches/build-cache-1 -type f -printf 'build-cache %s %p\n' 2>/dev/null
    for d in caches/jars-*; do
      [ -d "$d" ] && find "$d" -mindepth 1 -maxdepth 1 -type d -exec du -sb {} + | awk '{print "instrumented-jars", $1, $2}'
    done
    for d in caches/*/kotlin-dsl/scripts caches/*/kotlin-dsl/accessors; do
      [ -d "$d" ] && find "$d" -mindepth 1 -maxdepth 1 -type d -exec du -sb {} + | awk '{print "kotlin-dsl", $1, $2}'
    done
  } | sort -k3
}

case "$1" in
  record) list > /tmp/delta/before.txt ;;
  compare)
    list > /tmp/delta/after.txt
    python3 -I - /tmp/delta/before.txt /tmp/delta/after.txt <<'PY'
import sys
from collections import defaultdict
def load(p):
    d = {}
    for line in open(p):
        kind, size, path = line.rstrip("\n").split(" ", 2)
        d[path] = (kind, int(size))
    return d
before, after = load(sys.argv[1]), load(sys.argv[2])
rows = defaultdict(lambda: [0, 0, 0, 0, 0, 0])  # total n, total bytes, new n, new bytes, gone n, gone bytes
for path, (kind, size) in after.items():
    r = rows[kind]; r[0] += 1; r[1] += size
    if path not in before:
        r[2] += 1; r[3] += size
for path, (kind, size) in before.items():
    if path not in after:
        r = rows[kind]; r[4] += 1; r[5] += size
mb = lambda b: f"{b / 1048576:.1f}"
print("### delta: layer | units after | MB after | new units | new MB | gone units | gone MB")
for kind, r in sorted(rows.items()):
    print(f"delta: {kind} | {r[0]} | {mb(r[1])} | {r[2]} | {mb(r[3])} | {r[4]} | {mb(r[5])}")
PY
    ;;
esac
exit 0
