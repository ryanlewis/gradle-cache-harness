#!/usr/bin/env python3
"""Print a markdown table of saved harness runs: one row per run and provider.

    scripts/report.py results/13-cold results/14-warm ...

Columns are step durations in seconds, the runner image, configuration cache outcome of the
build step, and task outcome counts for the build (and test, when present) steps.
"""
import json
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ORDER = ["basic", "enhanced", "v5", "v5rc", "sim"]


def secs(step):
    if not step.get("startedAt") or not step.get("completedAt"):
        return None
    parse = lambda x: datetime.fromisoformat(x.replace("Z", "+00:00"))
    return int((parse(step["completedAt"]) - parse(step["startedAt"])).total_seconds())


def step_logs(log_path):
    logs = defaultdict(list)
    for line in log_path.read_text(errors="replace").splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3:
            logs[(parts[0], parts[1])].append(parts[2][29:])
    return logs


def tasks(text):
    m = re.search(r"(\d+) actionable tasks?: ([^\n]*)", text)
    if not m:
        return ""
    total = m.group(1)
    cached = re.search(r"(\d+) from cache", m.group(2))
    return f"{cached.group(1) if cached else 0} / {total}"


def row(run_dir, job, logs):
    provider = re.search(r"\((\w+)\)", job["name"]).group(1)
    steps = {s["name"]: s for s in job["steps"]}

    def duration(prefix, must=None):
        for name, s in steps.items():
            if name.startswith(prefix) and (must is None or must in name) and s.get("conclusion") != "skipped":
                return secs(s)
        return None

    label = {"basic": "v6 basic", "enhanced": "v6 enhanced", "v5": "v5", "v5rc": "v5", "sim": "v5"}[provider]
    restore = duration("Setup Gradle", label.split()[-1] if provider != "basic" else "basic")
    save = duration("Post Setup Gradle", label.split()[-1] if provider != "basic" else "basic")
    has_test = (job["name"], "Test") in logs
    build = "\n".join(logs.get((job["name"], "Build"), []))
    test = "\n".join(logs.get((job["name"], "Test"), []))
    image = re.search(r"Version: ([0-9.]+)", "\n".join(logs.get((job["name"], "Set up job"), [])))
    if "Reusing configuration cache" in build:
        cc = "reused"
    elif "configuration cache cannot be reused because" in build:
        cc = "miss: " + re.search(r"cannot be reused because ([^\n]*)", build).group(1).rstrip(".")[:60]
    elif "Calculating task graph" in build:
        cc = "miss: none stored"
    else:
        cc = "off"
    test_cell = ""
    if has_test:
        test_cell = f"{duration('Test')}" + (" (failed)" if "BUILD FAILED" in test else "")
    return provider, [
        re.sub(r"^(spring-)?\d+-", "", run_dir.name),
        provider,
        image.group(1).split(".")[-1] if image else "",
        restore,
        duration("Configure"),
        duration("Build"),
        test_cell,
        save,
        cc,
        tasks(build),
        tasks(test),
    ]


def main():
    header = ["Scenario", "Provider", "Image", "Restore", "Configure", "Build", "Test", "Save", "Config cache", "Build from cache", "Test from cache"]
    rows = []
    for arg in sys.argv[1:]:
        run_dir = Path(arg)
        run = json.loads((run_dir / "run.json").read_text())
        logs = step_logs(run_dir / "log.txt")
        found = [row(run_dir, j, logs) for j in run["jobs"] if j["name"].startswith("build")]
        found.sort(key=lambda r: ORDER.index(r[0]) if r[0] in ORDER else 99)
        rows.extend(r for _, r in found)
    keep = [i for i in range(len(header)) if any(r[i] not in ("", None) for r in rows)]
    print("| " + " | ".join(header[i] for i in keep) + " |")
    print("|" + "---|" * len(keep))
    last = None
    for r in rows:
        cells = ["" if v is None else str(v) for v in r]
        if cells[0] == last:
            cells[0] = ""
        else:
            last = cells[0]
        print("| " + " | ".join(cells[i] for i in keep) + " |")


main()
