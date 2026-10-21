#!/usr/bin/env bash
# Trigger one harness run for a scenario, wait for it, and save its results under results/.
#   scripts/run-scenario.sh cold|warm|buildfile|depbump
# cold deletes every cache entry in the repository first.
set -euo pipefail

scenario="$1"
cd "$(dirname "$0")/.."

if [ "$scenario" = cold ]; then
  gh cache delete --all --succeed-on-no-caches
fi

n=$(($(cut -d' ' -f2 scenario) + 1))
echo "$scenario $n" > scenario
git add scenario
git commit -q -m "chore: run $n ($scenario)"
git push -q

sha=$(git rev-parse HEAD)
run=""
for _ in $(seq 1 30); do
  run=$(gh run list --commit "$sha" --workflow harness --json databaseId --jq '.[0].databaseId // empty')
  [ -n "$run" ] && break
  sleep 5
done
[ -n "$run" ] || { echo "no run found for $sha" >&2; exit 1; }

gh run watch "$run" --interval 30 > /dev/null || true

out="results/$(printf '%02d' "$n")-$scenario"
mkdir -p "$out"
gh run view "$run" --json conclusion,jobs > "$out/run.json"
gh run view "$run" --log > "$out/log.txt"
echo "$run" > "$out/run-id"
echo "$out (run $run, $(jq -r .conclusion "$out/run.json"))"
