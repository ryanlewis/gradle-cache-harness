#!/usr/bin/env bash
# Print sizes and file counts of Gradle User Home and the project's .gradle directory.
set -uo pipefail

label="$1"
guh="${GRADLE_USER_HOME:-$HOME/.gradle}"
proj="$GITHUB_WORKSPACE/nia/.gradle"

echo "### snapshot $label $(date -u +%FT%T)"
if [ ! -d "$guh" ]; then
  echo "no Gradle User Home"
  exit 0
fi

echo "-- top level (KiB)"
du -sk "$guh"/* "$guh"/.[!.]* 2>/dev/null | sort -rn

echo "-- caches, two levels (KiB, files)"
find "$guh/caches" -mindepth 1 -maxdepth 2 -type d 2>/dev/null | sort | while read -r d; do
  printf '%10s %8s %s\n' "$(du -sk "$d" | cut -f1)" "$(find "$d" -type f | wc -l)" "${d#"$guh"/}"
done

echo "-- non-cache files in Gradle User Home"
find "$guh" -maxdepth 2 -type f -not -path '*/caches/*' 2>/dev/null | sort

echo "-- project .gradle (KiB)"
du -sk "$proj"/* 2>/dev/null | sort -rn
