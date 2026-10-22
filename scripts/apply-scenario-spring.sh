#!/usr/bin/env bash
# Change the checked-out Spring Boot build to match a scenario.
#   cold, warm  no change
#   buildfile   comment added to server/build.gradle
#   depbump     one library version changed in dependencies.gradle
#   srcedit     a private method added to one Java class in core, different on every run
# A "+conv" suffix (e.g. warm+conv) also applies build conventions: parallel execution and configuration cache.
set -euo pipefail

scenario="$1"
dir="$2"
run="${3:-0}"

case "$scenario" in
  *+conv)
    scenario="${scenario%+conv}"
    printf '\norg.gradle.parallel=true\norg.gradle.configuration-cache=true\norg.gradle.configuration-cache.problems=warn\n' >> "$dir/gradle.properties"
    echo "conventions applied"
    ;;
esac

case "$scenario" in
  cold | warm) ;;
  buildfile)
    echo "// harness: build file changed" >> "$dir/server/build.gradle"
    ;;
  depbump)
    sed -i "s/revCommonsIo = '2.18.0'/revCommonsIo = '2.19.0'/" "$dir/dependencies.gradle"
    grep -q "revCommonsIo = '2.19.0'" "$dir/dependencies.gradle"
    ;;
  srcedit)
    f="$dir/core/src/main/java/com/netflix/conductor/core/utils/DateTimeUtils.java"
    perl -0pi -e "s/\}\s*\z/    private static int harnessMarker$run() {\n        return $run;\n    }\n}\n/" "$f"
    ;;
  *)
    echo "unknown scenario: $scenario" >&2
    exit 1
    ;;
esac

echo "scenario: $scenario"
git -C "$dir" diff --stat
