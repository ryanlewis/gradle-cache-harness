#!/usr/bin/env bash
# Trigger one harness run, wait for it, and save its results under results/.
#   scripts/run.sh <suite> <scenario>
#   suite: android (workflow harness, file scenario) or spring (workflow spring, file scenario-spring)
#   scenario: cold | warm | buildfile | depbump | srcedit
# cold starts a new cache epoch: the run finds no earlier entries.
set -euo pipefail

suite="$1"
scenario="$2"
cd "$(dirname "$0")/.."

case "$suite" in
  android) file=scenario workflow=harness prefix="" ;;
  spring) file=scenario-spring workflow=spring prefix="spring-" ;;
  *) echo "unknown suite: $suite" >&2; exit 1 ;;
esac

[ -f "$file" ] || echo "cold 0 0" > "$file"
read -r _ last epoch < "$file"
epoch="${epoch:-0}"
n=$((last + 1))

if [ "${scenario%+conv}" = cold ]; then
  epoch=$((epoch + 1))
  # Keep the repository under the Actions cache limit: drop entries nobody has used for 90 minutes
  cutoff=$(date -u -v-90M +%FT%TZ 2>/dev/null || date -u -d '90 minutes ago' +%FT%TZ)
  gh cache list --limit 1000 --json key,lastAccessedAt \
    --jq ".[] | select(.lastAccessedAt < \"$cutoff\") | .key" | while read -r key; do
    gh cache delete "$key" > /dev/null || true
  done
fi
echo "$scenario $n $epoch" > "$file"

# The other suite may be committing and pushing from this repository at the same time
for _ in 1 2 3 4 5; do
  git add "$file" && git commit -q -m "chore: $suite run $n ($scenario)" && break
  sleep $((RANDOM % 5 + 2))
done
for _ in 1 2 3 4 5; do
  git push -q && break
  sleep $((RANDOM % 10 + 5))
done

sha=$(git rev-parse HEAD)
run=""
for _ in $(seq 1 30); do
  run=$(gh run list --commit "$sha" --workflow "$workflow" --json databaseId --jq '.[0].databaseId // empty')
  [ -n "$run" ] && break
  sleep 5
done
[ -n "$run" ] || { echo "no run found for $sha" >&2; exit 1; }

gh run watch "$run" --interval 30 > /dev/null || true

out="results/$prefix$(printf '%02d' "$n")-$scenario"
mkdir -p "$out"
gh run view "$run" --json conclusion,jobs > "$out/run.json"
gh run view "$run" --log > "$out/log.txt"
echo "$run" > "$out/run-id"
gh run download "$run" -D "$out/artifacts" || true
echo "$out (run $run, $(jq -r .conclusion "$out/run.json"))"
