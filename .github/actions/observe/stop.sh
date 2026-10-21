#!/usr/bin/env bash
set -uo pipefail

sudo pkill tcpdump || true
sleep 1

echo "::group::Gradle User Home after post steps"
"$GITHUB_WORKSPACE/scripts/snapshot.sh" after-post
echo "::endgroup::"

echo "::group::DNS names queried (whole job)"
grep -oE ' A{1,4}\? [^ ]+' /tmp/observe/tcpdump.txt | awk '{print $2}' | sort | uniq -c | sort -rn
echo "::endgroup::"

echo "::group::DNS queries with timestamps"
grep -E ' A{1,4}\? ' /tmp/observe/tcpdump.txt | awk '{print $1" "$2" "$(NF-1)}'
echo "::endgroup::"

echo "::group::DNS answers (name -> addresses)"
grep -E ' A [0-9]' /tmp/observe/tcpdump.txt | head -500
echo "::endgroup::"

echo "::group::Outbound TCP SYN destinations"
grep -E 'Flags \[S\]' /tmp/observe/tcpdump.txt | awk '{print $1" "$2" "$7}' | sed 's/:$//'
echo "::endgroup::"

echo "::group::Established sockets by node/java (deduplicated)"
grep -vE '^==' /tmp/observe/sockets.txt | awk '{print $3, $4, $5}' | sort -u
echo "::endgroup::"

echo "::group::tcpdump stderr"
cat /tmp/observe/tcpdump.err
echo "::endgroup::"
