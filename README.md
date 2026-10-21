# gradle-cache-harness

Measures the Gradle User Home caching providers in [`gradle/actions/setup-gradle`](https://github.com/gradle/actions) against the same build:

- `v6 enhanced` (default provider, closed-source `gradle-actions-caching`)
- `v6 basic` (`cache-provider: basic`)
- `v5` (the last release with open-source fine-grained caching)

The build is [android/nowinandroid](https://github.com/android/nowinandroid) at a pinned commit: Kotlin DSL, an included `build-logic` build, Android Gradle Plugin, many modules, configuration cache on.

Each provider is only observed from outside: step timings, cache entries created, Gradle User Home contents, and DNS lookups and TCP connections during the job. No provider code is unpacked or modified.

## Scenarios

| Scenario | Change to the build |
|---|---|
| `cold` | None. All cache entries are deleted first |
| `warm` | None |
| `buildfile` | A comment added to `app/build.gradle.kts` |
| `depbump` | One library version changed in `gradle/libs.versions.toml` |

Run one with `scripts/run-scenario.sh <scenario>`. It commits the `scenario` file to trigger the workflow, waits, and saves the run's jobs and logs under `results/`.

## Setup

The repository needs a `GRADLE_ENCRYPTION_KEY` secret (`openssl rand -base64 16`) so the providers that support it can save configuration cache data.
