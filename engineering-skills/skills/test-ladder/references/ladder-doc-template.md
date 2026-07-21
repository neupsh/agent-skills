# Template: docs/testing-ladder.md

Copy this into the target repo as `docs/testing-ladder.md`, fill in real values, and keep it updated in the same PR as any seam/tier change (see the **repo-truth** skill). Placeholder values are written to fail loudly if pasted into commands.

```markdown
# Testing Ladder

Cost-tiered test strategy for this repo. Rule: every behavior is tested at the
cheapest tier that can express it; every bug fix ships a regression test at the
lowest tier that can express the bug (push-down rule — see the test-ladder skill).

## Tiers

| Tier | Command | Per-run cost | Per-run time | What it catches | Known gaps |
|------|---------|--------------|--------------|-----------------|------------|
| T0 unit + fakes | `REPLACE_ME__e.g._go test ./...` | $0 | ~Xs | logic, state machines, retries | — |
| T1 protocol fakes + replay | `REPLACE_ME__e.g._go test -tags=protocol ./...` | $0 | ~Xs | wire format, streaming semantics, recorded provider quirks | recordings for <provider> predate API vN |
| T2 local substitutes | `REPLACE_ME__command` (requires: REPLACE_ME__local model / sandbox creds) | ~$0 | ~Xm | full pipeline vs real-ish behavior | does NOT validate hosted-provider quirks |
| T3 metered smoke | `REPLACE_ME__e.g._go test -tags=metered ./smoke/...` | ~$X.XX | ~Xm | provider drift, auth, quotas | nondeterministic; see flaky policy |
| T4 E2E | `REPLACE_ME__command_or_pipeline_link` | ~$X.XX | ~Xm | deploy config, cross-service wiring | pre-release only |

## CI mapping

- T0+T1: every push, merge-blocking (workflow: REPLACE_ME__link).
- T2: REPLACE_ME (on PR / nightly + why).
- T3: nightly at REPLACE_ME + label `run-metered`; secrets isolated from fork PRs.
- T4: pre-release / schedule REPLACE_ME.

## Budgets

- T3: max $X.XX per run (enforced: REPLACE_ME__how), $XX/month cap on key REPLACE_ME__key_name_not_value.
- T4: max $X.XX per run.
- Before running T3/T4 manually, state which cheaper tier was tried and why it was insufficient.

## Flaky policy (T2+)

- Retry count: 1. Second failure files/updates an issue.
- Latency assertions: statistical only (pN over ≥N reps); thresholds and provenance listed here:
  - REPLACE_ME: p95 first-token < Xms over 20 reps (baseline measured YYYY-MM-DD)
- T0/T1 flakes are bugs: fix or delete same day, no quarantine.

## Quarantine

| Test | Tier | Reason | Owner | Expiry |
|------|------|--------|-------|--------|
| (none) | | | | |

Expired entries fail CI until fixed or deleted.

## Seam table (from last audit: YYYY-MM-DD)

| Dependency | Port? | Fake injectable? | Rehomeable? | Recorded traffic? | Backlog |
|---|---|---|---|---|---|
| REPLACE_ME | | | | | |

## Fixtures & seeding

- Seed script: `REPLACE_ME__e.g._scripts/seed-test-env.sh` — creates all fixture
  entities (test accounts/agents) idempotently. Never rely on IDs not created by
  this script.
- Recordings: `testdata/recordings/` — sanitized; re-record when T3 detects drift.
- Committed placeholder values use the `REPLACE_ME__` prefix; app code and tests
  reject values with that prefix at startup, printing a pointer to the seed script.
```

## CI workflow sketches

Adapt to the repo's CI system; these are GitHub-Actions-shaped.

**Merge-blocking T0/T1 (every push):**

```yaml
on: [push, pull_request]
jobs:
  ladder-t0-t1:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: <toolchain setup>
      - run: <T0 command>
      - run: <T1 command>
# Then mark this job required in branch protection — the gate is the point.
```

**Nightly + label-triggered T3 with secrets isolation:**

```yaml
on:
  schedule: [{cron: "0 6 * * *"}]
  pull_request:
    types: [labeled]
jobs:
  metered-smoke:
    if: github.event_name == 'schedule' || github.event.label.name == 'run-metered'
    runs-on: ubuntu-latest
    environment: metered   # environment-protected secrets; not exposed to fork PRs
    steps:
      - uses: actions/checkout@v4
      - run: <T3 command>
        env:
          PROVIDER_KEY: ${{ secrets.PROVIDER_KEY }}
      - if: failure()
        run: <open/append tracking issue with logs>   # advisory, never merge-blocking
```

Notes:
- Never let `pull_request` events from forks reach metered secrets; the `environment:` protection plus label gating (labels applicable only by maintainers) is the minimum.
- If the repo auto-deploys on merge to the default branch and has **no** merge-blocking test job: create the T0/T1 job and branch-protection rule as the first PR, before feature work (SKILL.md, CI mapping).
