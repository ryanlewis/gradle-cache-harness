#!/usr/bin/env python3
"""Summarise a Gradle build operation trace (-Dorg.gradle.internal.operations.trace=<base>, file <base>-log.txt).

    scripts/optrace.py results/NN-x/artifacts/optrace-v5/build-log.txt [--tasks N]

Prints the build's top-level phases, then wall-clock time per category (overlapping operations merged,
so parallel work is not double counted) and the summed time, then the slowest tasks and task names.
"""
import json
import sys
from collections import defaultdict

CATEGORIES = [
    # (category, predicate on (detailsClassName, displayName, details))
    ("configuration cache: fingerprint check", lambda c, n, d: "FingerprintCheck" in c),
    ("configuration cache: load", lambda c, n, d: n.startswith("Load configuration cache state")),
    ("configuration cache: store", lambda c, n, d: n.startswith("Store configuration cache state")),
    ("script compilation", lambda c, n, d: n.startswith("Compile script") or "CompileScript" in c),
    ("project configuration", lambda c, n, d: c.endswith("LifecycleProjectEvaluator$ConfigureProjectDetails")),
    ("dependency resolution", lambda c, n, d: c.endswith("ResolveConfigurationResolutionBuildOperationDetails")),
    ("artifact download", lambda c, n, d: c.endswith("DownloadArtifactBuildOperationType$DetailsImpl")),
    ("remote resource read", lambda c, n, d: "ExternalResourceAccessor$ReadOperationDetails" in c),
    ("artifact transform execution", lambda c, n, d: c.endswith("ExecuteTransformActionBuildOperationType$1")),
    ("task execution (all)", lambda c, n, d: c.endswith("ExecuteTaskBuildOperationDetails")),
    ("task actions", lambda c, n, d: c.endswith("ExecuteTaskActionBuildOperationType$1")),
    ("build cache: unpack", lambda c, n, d: c.endswith("UnpackOperationDetails")),
    ("build cache: pack", lambda c, n, d: c.endswith("PackOperationDetails")),
    ("build cache: load", lambda c, n, d: "LoadDetails" in c and "BuildCache" in c),
    ("build cache: store", lambda c, n, d: "StoreDetails" in c and "BuildCache" in c),
]


def load(path):
    starts, ops = {}, []
    with open(path, errors="replace") as f:
        for line in f:
            if not line.startswith("{"):
                continue
            try:
                o = json.loads(line)
            except ValueError:
                continue
            if "startTime" in o:
                starts[o["id"]] = o
            elif "endTime" in o and o.get("id") in starts:
                s = starts.pop(o["id"])
                s["endTime"] = o["endTime"]
                s["result"] = o.get("result")
                ops.append(s)
    return ops


def union(intervals):
    total, end = 0, None
    for a, b in sorted(intervals):
        if end is None or a > end:
            total += b - a
            end = b
        elif b > end:
            total += b - end
            end = b
    return total


def main():
    path = sys.argv[1]
    top_n = int(sys.argv[sys.argv.index("--tasks") + 1]) if "--tasks" in sys.argv else 15
    ops = load(path)
    root = min(ops, key=lambda o: o["startTime"])
    wall = root["endTime"] - root["startTime"]
    print(f"# {path}\nwall clock: {wall / 1000:.1f}s")

    print("\n## phases (children of the root operation, >= 0.5s)")
    for o in sorted((o for o in ops if o.get("parentId") == root["id"]), key=lambda o: o["startTime"]):
        dur = o["endTime"] - o["startTime"]
        if dur >= 500:
            print(f"{dur / 1000:8.1f}s  {o['displayName']}")

    print("\n## categories: wall-clock (merged) / summed / count")
    buckets = defaultdict(list)
    for o in ops:
        c, n, d = o.get("detailsClassName") or "", o.get("displayName") or "", o.get("details") or {}
        for name, pred in CATEGORIES:
            if pred(c, n, d):
                buckets[name].append((o["startTime"], o["endTime"]))
    for name, _ in CATEGORIES:
        iv = buckets.get(name)
        if iv:
            print(f"{union(iv) / 1000:8.1f}s {sum(b - a for a, b in iv) / 1000:9.1f}s {len(iv):7d}  {name}")

    tasks = []
    for o in ops:
        if (o.get("detailsClassName") or "").endswith("ExecuteTaskBuildOperationDetails"):
            d = o.get("details") or {}
            tasks.append((o["endTime"] - o["startTime"], d.get("buildPath", ""), d.get("taskPath", o.get("displayName")), o.get("result") or {}))

    def state(r):
        return r.get("skipMessage") or "EXECUTED"

    print(f"\n## slowest {top_n} tasks")
    for dur, build, task, r in sorted(tasks, key=lambda t: -t[0])[:top_n]:
        reason = r.get("cachingDisabledReasonMessage") or ""
        print(f"{dur / 1000:7.1f}s  {build}{task}  [{state(r)}] {reason}")

    print("\n## by task name (summed seconds, count, executed-not-cacheable count), top 25")
    groups = defaultdict(lambda: [0, 0, 0])
    for dur, build, task, r in tasks:
        name = task.rsplit(":", 1)[-1]
        g = groups[name]
        g[0] += dur
        g[1] += 1
        if state(r) == "EXECUTED" and r.get("cachingDisabledReasonCategory"):
            g[2] += 1
    for name, (dur, n, nc) in sorted(groups.items(), key=lambda kv: -kv[1][0])[:25]:
        print(f"{dur / 1000:8.1f}s {n:4d} {nc:4d}  {name}")

    print("\n## caching disabled reasons (executed tasks)")
    reasons = defaultdict(lambda: [0, 0])
    for dur, build, task, r in tasks:
        cat = r.get("cachingDisabledReasonCategory")
        if cat and state(r) == "EXECUTED":
            reasons[f"{cat}: {r.get('cachingDisabledReasonMessage', '')}"][0] += 1
            reasons[f"{cat}: {r.get('cachingDisabledReasonMessage', '')}"][1] += dur
    for k, (n, dur) in sorted(reasons.items(), key=lambda kv: -kv[1][1]):
        print(f"{dur / 1000:8.1f}s {n:4d}  {k}")


main()
