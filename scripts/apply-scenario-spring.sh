#!/usr/bin/env bash
# Change the checked-out Spring Boot build to match a scenario.
#   cold, warm  no change
#   buildfile   comment added to server/build.gradle
#   depbump     one library version changed in dependencies.gradle
#   srcedit     an unused constant added to one Java class in core, different on every run
# A "+conv" suffix (e.g. warm+conv) also turns on parallel execution.
# The configuration cache is left off: Spotless 6.25's Groovy extension can't be serialised, so this build fails to load it.
set -euo pipefail

scenario="$1"
dir="$2"
run="${3:-0}"

case "$scenario" in
  *+conv)
    scenario="${scenario%+conv}"
    printf '\norg.gradle.parallel=true\n' >> "$dir/gradle.properties"
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
    # Adds an unused constant: the class file changes, the formatter accepts it and no test can see it
    f="$dir/core/src/main/java/com/netflix/conductor/core/utils/DateTimeUtils.java"
    sed -i "s/^public class DateTimeUtils {$/public class DateTimeUtils {\n\n    private static final int HARNESS_MARKER = $run;/" "$f"
    grep -q "HARNESS_MARKER = $run;" "$f"
    ;;
  *)
    echo "unknown scenario: $scenario" >&2
    exit 1
    ;;
esac

echo "scenario: $scenario"
git -C "$dir" diff --stat
