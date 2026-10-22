# gradle-cache-harness

Measures Gradle caching on GitHub Actions: the providers in [`gradle/actions/setup-gradle`](https://github.com/gradle/actions), and variants that model parts of the ideal design described in [gradle-ci-caching](https://github.com/ryanlewis/gradle-ci-caching). Each runs against the same pinned builds.

Every provider is observed from outside only:
- step timings;
- cache entries created;
- Gradle User Home contents before and after the build;
- Gradle build operation traces;
- DNS lookups and TCP connections for the whole job.

No provider code is unpacked or modified.

## Suites

| Suite | Workflow | Build | Gradle calls |
|---|---|---|---|
| `android` | `harness.yml` | [android/nowinandroid](https://github.com/android/nowinandroid): AGP, Kotlin DSL, included `build-logic`, configuration cache | `help`, `:app:assembleDemoDebug` |
| `spring` | `spring.yml` | [conductor-oss/conductor](https://github.com/conductor-oss/conductor): Spring Boot REST and gRPC server, ~52 modules | `help`, `build -x test`, `:conductor-common:test :conductor-core:test` |

## Variants

| Variant | What it is |
|---|---|
| `enhanced` | setup-gradle v6, default provider (closed-source `gradle-actions-caching`) |
| `basic` | setup-gradle v6, `cache-provider: basic` |
| `v5` | setup-gradle v5.0.2, the last release with open-source fine-grained caching |
| `sim` (android) | v5, plus task outputs in a separate store that is never cleaned per job, plus project state (`build-logic` outputs, `src/*/generated`) restored before Gradle starts, keyed by build-logic inputs and kernel release |
| `v5rc` (spring) | v5, plus the separate task output store |

## Scenarios

| Scenario | Change to the build |
|---|---|
| `cold` | None. Starts a new cache epoch, so no earlier entries are found |
| `warm` | None |
| `srcedit` | One source file changed, differently on every run |
| `buildfile` | A comment added to a build script |
| `depbump` | One library version changed |
| `<scenario>+conv` (spring) | Also turns on parallel execution |

## Scripts

| Script | Use |
|---|---|
| `scripts/run.sh <suite> <scenario>` | Commits the scenario file to trigger the workflow, waits, and saves the run's jobs, logs and traces under `results/` |
| `scripts/report.py <result dirs>` | Markdown table: step times, runner image, configuration cache outcome and reason, tasks from cache |
| `scripts/optrace.py <trace>` | Summary of a build operation trace: phases, wall-clock and summed time per category, slowest tasks, cacheability reasons |
| `scripts/apply-scenario*.sh`, `scripts/snapshot.sh`, `scripts/delta.sh` | Run on the runner: apply a scenario, list Gradle User Home, report what the build added per cache layer |

## Setup

The repository needs a `GRADLE_ENCRYPTION_KEY` secret (`openssl rand -base64 16`) so the providers that support it can save configuration cache data.

Runs stay under the repository's GitHub Actions cache limit (10 GB). Above it, GitHub evicts the least recently used entries, which turns some warm runs cold. `run.sh` prunes entries unused for 90 minutes when a cold run starts.
