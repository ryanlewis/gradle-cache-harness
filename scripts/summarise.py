#!/usr/bin/env python3
"""Summarise saved harness runs: step timings, Gradle outcomes, cache activity and network per provider.

    scripts/summarise.py results/00-cold [results/01-warm ...]
"""
import json
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

STEPS = ["Setup Gradle", "Snapshot after restore", "Configure", "Build", "Post Setup Gradle", "Post Start observer"]


def seconds(step):
    if not step.get("startedAt") or not step.get("completedAt"):
        return None
    start = datetime.fromisoformat(step["startedAt"].replace("Z", "+00:00"))
    end = datetime.fromisoformat(step["completedAt"].replace("Z", "+00:00"))
    return int((end - start).total_seconds())


def split_log(log_text):
    """gh run view --log lines are 'job<TAB>step<TAB>timestamp text'."""
    jobs = defaultdict(list)
    for line in log_text.splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3:
            jobs[parts[0]].append((parts[1], parts[2][29:] if len(parts[2]) > 29 else parts[2]))
    return jobs


def provider(job_name):
    m = re.search(r"\((\w+)\)", job_name)
    return m.group(1) if m else job_name


def summarise(run_dir):
    run = json.loads((run_dir / "run.json").read_text())
    logs = split_log((run_dir / "log.txt").read_text(errors="replace"))
    print(f"\n## {run_dir.name} ({run['conclusion']})")

    for job in run["jobs"]:
        if not job["name"].startswith("build"):
            continue
        name = provider(job["name"])
        print(f"\n### {name}: {job['conclusion']}")
        timings = []
        for step in job["steps"]:
            label = step["name"]
            if any(label.startswith(s) or s in label for s in STEPS):
                timings.append(f"{label}={seconds(step)}s")
        print("steps: " + ", ".join(timings))

        lines = [text for _, text in next((v for k, v in logs.items() if name in k), [])]
        joined = "\n".join(lines)
        for pattern in [
            r"BUILD SUCCESSFUL in .*",
            r"Reusing configuration cache.*",
            r"Configuration cache entry (stored|reused|discarded).*",
            r"Calculating task graph as .*",
            r"\d+ actionable tasks?: .*",
        ]:
            for hit in re.findall(pattern, joined):
                print(f"  gradle: {hit if isinstance(hit, str) else ''}".rstrip())
        for m in re.finditer(r"(Restored|Saved|Cache hit|cache not found|Not restoring|Not saving|Caching of project|Project state|Enhanced Caching|Basic Caching|did not find)[^\n]{0,200}", joined):
            print(f"  cache: {m.group(0)}")
        names = re.findall(r"^\s*(\d+) (\S+)$", joined.split("DNS names queried")[1].split("DNS queries with")[0], re.M) if "DNS names queried" in joined else []
        print("  dns: " + ", ".join(f"{n}({c})" for c, n in names))


for arg in sys.argv[1:]:
    summarise(Path(arg))
