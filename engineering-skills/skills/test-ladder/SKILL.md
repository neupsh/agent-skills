---
name: test-ladder
description: Designs and maintains a cost-tiered testing ladder (T0 unit fakes → T4 prod-like E2E) for systems whose full-fidelity tests are expensive, slow, or nondeterministic — paid AI/voice APIs, brokerage/exchange APIs, telephony, GPU pipelines. Use when adding tests to a repo with external paid/flaky dependencies, when deciding which tier a regression test belongs in, when a bug is "only reproducible in production", when setting up CI gates for such a repo, or when auditing why real-API costs or flaky tests are growing.
metadata: {version: 1.0}
---

# test-ladder

A testing ladder is a cost-ordered set of tiers. Every behavior gets tested at the **cheapest tier that can express it**, and every tier's fidelity limits are stated honestly. The two operations you perform with this skill: (1) **audit and build** the ladder for a repo, (2) **push bugs down** the ladder when you fix them.

## When to use

- The repo talks to paid, metered, rate-limited, or nondeterministic externals: LLM/STT/TTS providers, exchanges/brokerages, telephony, payment rails, GPUs.
- You fixed a bug found in staging/production and must decide where the regression test lives.
- CI has no merge gate, or the only tests that exist hit real APIs.
- Someone proposes "just run it against the real API" as the test plan.

## When NOT to use

- Pure-local codebases (CLI tools, libraries with no network I/O): ordinary unit + integration tests suffice; don't build a five-tier ladder for a string parser.
- One-line fixes with an existing obvious test file: add the test where its siblings live, skip the audit.
- Prototypes explicitly declared throwaway. (But the moment one is promoted, run the seam audit before feature work.)

Proportionality: a small task in a repo that already has a ladder means *one* decision — "which tier does my test go in" — not a re-audit.

## The ladder

| Tier | Name | Runs against | Cost | Deterministic | Catches |
|------|------|-------------|------|---------------|---------|
| T0 | Pure unit + in-process fakes | Scripted fakes injected via ports | free, ms | yes | your logic: state machines, retries, parsing, error paths |
| T1 | Protocol-level fakes + record-replay | Local fake server speaking the **real wire protocol**; fixtures recorded from real traffic | free, seconds | yes | serialization, framing, streaming semantics, protocol edge cases, provider quirks *that were recorded* |
| T2 | Local substitutes | Open-source stand-ins with real behavior: local LLM (Ollama), local STT/TTS, paper-trading/sandbox endpoints | free/cheap, seconds–minutes | mostly | full pipeline integration, real latency shapes, real-ish payloads |
| T3 | Metered real-API smoke | The actual paid provider, tiny tagged suite, budget-capped | $ per run | no | provider drift, auth, quota, undocumented behavior changes |
| T4 | Full E2E / prod-like | Deployed stack, real providers, real clients | $$, minutes–hours | no | deployment config, cross-service wiring, everything at once |

Crisp definitions:

- **T0** — no network, no subprocess. Fakes are hand-scripted objects implementing your ports ("return these 3 transcript events, then error"). If you can't write a T0 test for a component, the component lacks a seam — see the audit below.
- **T1** — a real socket/HTTP/WebSocket server running in the test process or as a local binary, speaking the provider's actual wire format. Two flavors: (a) hand-built fake server for scripted scenarios, (b) **record-replay**: capture real provider traffic once (sanitized), replay it byte-faithfully. T1 is the highest deterministic tier and therefore the workhorse for regression tests of protocol bugs.
- **T2** — a different *implementation* with genuinely real behavior: Ollama instead of a hosted LLM, a local STT engine, an exchange's paper-trading endpoint. Validates your pipeline under realistic conditions but **not** the paid provider's quirks (see Fidelity honesty).
- **T3** — real API, real money. Small (single-digit test count), tagged (`//go:build metered`, `@pytest.mark.metered`, etc.), budget-capped, explicit flaky policy. Exists to detect provider drift, not to test your logic.
- **T4** — the deployed system. Scheduled or pre-release only. Never the tier where a bug's regression test lives long-term.

**Classifying inherited ad-hoc "live smoke" assets:** classify by what the test *exercises*, not what it is called. A standalone script/test hitting the real provider API directly is T3-shaped — shrink it into the tiny tagged tripwire. One exercising the full deployed stack is T4 — schedule it pre-release. Most inherited manual smokes should be split into both.

## Seam audit (run this when entering a repo or before infra work)

For **each** external dependency, answer four questions and build a seam table:

1. **Port?** Is there an interface/trait/protocol your code depends on, rather than the vendor SDK directly?
2. **Fake injectable?** Can a test construct the system with a scripted fake for that port, without patching/monkeypatching internals?
3. **Rehomeable?** Can the *real* adapter be pointed at a local base URL (config/env var), enabling T1 fake servers and T2 substitutes?
4. **Recorded traffic?** Do sanitized captures of real provider traffic exist in the repo for replay?

Grep heuristics for finding dependencies and missing seams:

```bash
# External endpoints hardcoded (missing rehome seam):
grep -rEn 'https?://[a-z0-9.-]+\.(com|ai|io|net)' --include='*.{go,py,ts,rs}' src/ pkg/ services/ 2>/dev/null | grep -v test
# Vendor SDKs imported directly in business logic (missing port):
# (illustrative list — replace/extend with the vendor names found in the repo's dependency manifest, Step 1 of references/seam-audit.md)
grep -rn 'openai\|anthropic\|deepgram\|elevenlabs\|twilio\|alpaca\|binance' --include='*.go' --include='*.py' --include='*.ts' | grep -vi 'adapter\|provider\|client\|_test\|mock\|fake'
# Provider switch statements (seams likely exist — find the port there):
grep -rn 'case "openai"\|case "google"\|switch.*[Pp]rovider' --include='*.go' --include='*.ts'
# Constructors taking concrete clients instead of interfaces:
grep -rn 'func New.*\*http\.Client\|def __init__.*api_key' | grep -v test
```

Output a table (one row per dependency, columns = the 4 questions). **Every "no" is a backlog item**, sized as infra work, filed before the next feature that touches that dependency. The audit's final artifact is `docs/testing-ladder.md` (template: `references/ladder-doc-template.md`) containing the tier table, CI mapping, budgets, and this seam table — an audit that ends as chat prose is incomplete. Full procedure, table template, and seam-fixing recipes: read `references/seam-audit.md` when doing the audit.

## The push-down rule (the centerpiece — apply on every bug fix)

> Every bug found at tier N ships with a regression test at the **lowest** tier that can express it. If no lower tier can express it, that is a **missing seam** — file it as infra work in the same PR or issue.

Procedure when fixing a bug found in T3/T4/production:

1. State what the bug actually was, mechanically (not "TTS was broken" but "provider closed the stream without a final frame and our reader blocked forever").
2. Walk down the ladder: can T0 express it? (Usually yes if it's your state machine.) Can T1? (Yes if it's wire behavior — replay the pathological traffic.) Stop at the lowest tier that can.
3. Write the test there. It must fail on the pre-fix code — verify by reverting the fix or asserting on the old behavior.
4. If you had to stop at T3/T4, the fix PR includes a filed issue: "missing seam: cannot fake X's streaming close behavior locally" — with the seam-table row it corresponds to.

**Worked example.** A voice platform where the only paid-API-free tier was unit mocks. A streaming-TTS hang appeared only on real production calls: the provider sometimes sent response headers late, and the client's read loop had no deadline. Wrong outcome: fix the timeout, note "verified manually on a prod call," done. Right outcome: the hang is *wire behavior* — expressible at T1. The fix ships with a T1 test: a local HTTP server that accepts the connection and stalls before writing headers; assert the client errors within the deadline and the retry path engages. Now the regression test runs on every push for free, forever. The manual prod call was the *discovery* mechanism, never the *regression* mechanism.

**Anti-pattern: "verified in prod" as the permanent test.** Failure it causes: the bug regresses six months later, nobody re-runs the manual check, and you re-debug it from scratch at production cost.

**Anti-pattern: pushing down only to where a test is *convenient*.** A protocol bug "tested" with a T0 mock that returns a clean error your parser never actually receives — the test passes forever and protects nothing. Push down to the lowest tier that can express *the actual failure*, not a sanitized paraphrase of it.

## Fidelity honesty

- Local substitutes (T2) validate **your pipeline logic**, not the provider's quirks. Ollama proving your prompt-assembly and streaming plumbing work says nothing about how the hosted provider tokenizes, rate-limits, or closes streams.
- Provider-protocol bugs need T1 replay **from recorded real traffic** or T3 real calls. A hand-written fake encodes your *beliefs* about the protocol; a recording encodes the *facts*.
- **Never report coverage a tier cannot deliver.** "Covered by T2" for a provider-quirk bug is a false statement — say "pipeline covered at T2; provider behavior unverified locally, caught by T3 nightly."
- **Keep exactly one metered smoke tier alive.** Zero real-API coverage rots silently: provider changes an auth flow or deprecates a field, and you learn from a customer. One small, budget-capped T3 suite on a schedule is the tripwire. If T3 is currently disabled/broken, re-enabling it outranks adding more T0 tests (see the sequencing precedence under CI mapping for how this ranks against other infra work).

## Determinism & flakiness policy

- T0/T1 fakes are **deterministic by default**: seeded randomness, injected clocks, scripted event order. A flaky T0/T1 test is a bug in the test — fix or delete same day; never retry-loop it.
- Nondeterministic tiers (T2 latency, T3, T4) get explicit policy, written in the ladder doc:
  - fixed retry count (e.g., 1 retry, then fail — never unbounded),
  - a **quarantine list** with owner + expiry date per test; expired quarantine = test is deleted or fixed, no third option,
  - latency and quality claims use **statistical assertions over N repetitions** (e.g., "p95 of 20 runs < 800ms"), never a single-shot threshold.
- **Never assert wall-clock latency in tiers without a controlled clock.** In T0/T1, inject a fake clock and assert on it. A `time.Sleep`-and-measure test in CI is a flake generator; the failure it causes is a team trained to ignore red CI.
- **Interleaving nondeterminism is a distinct axis from timing.** Scripted event order and injected clocks pin down *when* events fire, not *which order* concurrent events interleave in — the dominant bug axis for reconciliation/orchestration state machines (a fill event racing a cancel, a reconnect racing an in-flight request). At T0, explore interleavings deliberately: property-based testing over valid *and invalid* event orderings (proptest / hypothesis / fast-check) against the state machine's transition table, plus model checkers and race detectors (loom for Rust, `go test -race` for Go) for lock-level races.

## Cost accounting

- The repo documents **per-run dollars and minutes for every tier** (see Project binding). Unknown cost = measure once and write it down.
- T3/T4 have budget caps (per-run and per-month). Enforce mechanically where possible (spend-limited API keys, sandbox accounts); at minimum, document the cap and the current burn.
- **Capital at risk is not API spend.** When the metered tier can move real money or open real positions (brokerage/exchange/payment rails), "budget cap" must mean **bounded downside enforced provider-side**: max order size / notional / position limits configured on the dedicated test account, a testnet or paper account preferred for anything beyond the tripwire, and a documented kill-switch for runaway test loops. A bug in the test harness itself — e.g., an unbounded retry placing orders — must be bounded by account-level limits, not by harness code.
- **Before any expensive run, state which cheaper tier was tried and why it was insufficient.** "Running T4 because the bug involves cross-service deploy config, which T0–T2 cannot express" is valid. "Running T4 to see if the fix works" when a T1 test exists is not.

## CI mapping

| Tier | When | Gate |
|------|------|------|
| T0 + T1 | every push | **merge-blocking** |
| T2 | on PR, where runners allow (model weights, sandbox creds); else nightly | merge-blocking if fast enough, else advisory |
| T3 | nightly and/or label-triggered (`run-metered`); secrets isolated from fork PRs | advisory with alerting; failures open an issue |
| T4 | pre-release / scheduled | release-blocking |

- **No production deploy path without at least T0/T1 green.** If the repo deploys on merge and has no merge-blocking test gate, **adding that gate is the first task — before any feature work.** Ship it with whatever T0 tests exist, even if thin; the gate creates the pressure that grows the suite.
- T3 secrets never available to untrusted PR contexts. Label-trigger + environment protection, or nightly-only.

**Sequencing precedence** (when this skill's rules compete for the top of the backlog):
1. The merge-blocking T0/T1 CI gate — hard override, before everything.
2. Seam/infra work for dependencies implicated in recurring production bugs.
3. Keep or restore exactly one **scheduled** T3 tripwire — a manual-only smoke does **not** count as "alive".
4. The remaining seam backlog, ordered by current T3/T4 spend.

## Fixtures & test data

- Seeding scripts and fixture entities (test accounts, test agents, sandbox credentials *references*) are **checked into the repo**, sanitized. Recorded traffic is scrubbed of keys/PII before commit.
- **Never tribal-knowledge IDs** — a test-account ID living in one person's head, a chat log, or an agent's memory file is an outage waiting for the person/context to be absent. If you find yourself told "use agent 1234, it's the one with credentials," your next action is committing a seeding script or fixtures doc that makes that fact reproducible.
- Placeholder values in committed configs must **fail loudly** with a pointer: `API_KEY=REPLACE_ME__see_scripts/seed-test-env.sh`, and the code rejects `REPLACE_ME` prefixes at startup with that same pointer. Silent placeholder acceptance produces the worst bug class: tests that pass against nothing.

Recipes for building fakes, record-replay harnesses, local substitutes, and metered-smoke suites: read `references/tier-recipes.md` when implementing a tier.

## Project binding

Project-specific facts do **not** live in this skill. Commands, per-tier costs, fixture IDs, sandbox account setup, budget caps, and quarantine lists live in the project repo — look for them in `CLAUDE.md`, a project-local skill, or `docs/testing-ladder.md`. Never hardcode a provider name, price, or account ID from this skill into work product.

Create and maintain `docs/testing-ladder.md` in each repo you apply this skill to: one table mapping **tier → command → per-run cost/time → what it catches → known gaps**, plus the quarantine list and budget caps. Update it in the same PR whenever a seam is added or a tier's command changes — a stale ladder doc is worse than none (cross-ref the **repo-truth** skill for keeping docs synced with reality). Template: `references/ladder-doc-template.md`.

## Sibling skills

- **ports-and-modules** — the seam audit's "fix" column is that skill's territory: introducing ports, injecting adapters. Read it when a seam-table "no" needs structural surgery.
- **local-ai-stack** — how to actually stand up T2 substitutes (local LLM/STT/TTS serving).
- **train-voice-models** — when T2 needs a local voice model that doesn't exist off the shelf.
- **repo-truth** — keeping `docs/testing-ladder.md` and fixture docs honest and current.
- **tech-lead** — sequencing: when the seam backlog competes with features, that skill owns the prioritization call (this skill's only hard override: the T0/T1 CI gate comes first).

## References

- `references/seam-audit.md` — full audit procedure, seam table template, grep patterns per language, seam-fixing recipes. Read when auditing a repo or filing seam backlog items.
- `references/tier-recipes.md` — implementation recipes: scripted fakes, protocol fake servers, record-replay capture/sanitize/replay, local substitutes, metered smoke design, statistical latency assertions, quarantine mechanics. Read when building or extending a tier.
- `references/ladder-doc-template.md` — copy-paste template for `docs/testing-ladder.md` and CI workflow sketches. Read when creating the ladder doc or wiring CI.
