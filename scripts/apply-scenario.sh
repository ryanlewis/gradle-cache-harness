#!/usr/bin/env bash
# Change the checked-out build to match a scenario.
#   cold, warm  no change
#   buildfile   comment added to app/build.gradle.kts
#   depbump     one library version changed in the version catalogue
#   srcedit     a private function added to one Kotlin source file, different on every run
set -euo pipefail

scenario="$1"
dir="$2"
run="${3:-0}"

case "$scenario" in
  cold | warm) ;;
  buildfile)
    echo "// harness: build file changed" >> "$dir/app/build.gradle.kts"
    ;;
  depbump)
    sed -i 's/^androidxBrowser = "1.8.0"/androidxBrowser = "1.9.0"/' "$dir/gradle/libs.versions.toml"
    grep -q '^androidxBrowser = "1.9.0"' "$dir/gradle/libs.versions.toml"
    ;;
  srcedit)
    f="$dir/feature/foryou/impl/src/main/kotlin/com/google/samples/apps/nowinandroid/feature/foryou/impl/OnboardingUiState.kt"
    printf '\nprivate fun harnessMarker%s() = %s\n' "$run" "$run" >> "$f"
    ;;
  *)
    echo "unknown scenario: $scenario" >&2
    exit 1
    ;;
esac

echo "scenario: $scenario"
git -C "$dir" diff --stat
