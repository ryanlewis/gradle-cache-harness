#!/usr/bin/env bash
set -euo pipefail

mkdir -p /tmp/observe
date +%s > /tmp/observe/start

# DNS queries and outbound TCP SYNs, with wall-clock timestamps
sudo nohup tcpdump -i any -l -n -tttt \
  'port 53 or (tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0)' \
  > /tmp/observe/tcpdump.txt 2> /tmp/observe/tcpdump.err &

# Open sockets owned by node processes, sampled every second (catches action processes)
nohup bash -c 'while true; do echo "== $(date -u +%FT%T)"; sudo ss -tnp state established 2>/dev/null | grep -E "node|java" || true; sleep 1; done' \
  > /tmp/observe/sockets.txt 2>&1 &

sleep 1
echo "observer started"
