# Tier implementation recipes

Concrete build instructions per tier. Language examples are Go/Python/TS-flavored pseudocode; adapt to the repo's stack.

## T0 — scripted in-process fakes

- One fake per **port**, hand-written, living next to the port or under `internal/testfakes/`. Prefer hand-written scriptable fakes over mock-generation frameworks for stateful/streaming ports — generated mocks encode call expectations, not behavior, and rot on refactor.
- The fake's API is a **script**: the test enqueues events/responses, the fake plays them back.

```go
fake := &FakeSTT{Script: []STTEvent{
    {Type: Partial, Text: "hel"},
    {Type: Partial, Text: "hello"},
    {Type: Err, Err: io.ErrUnexpectedEOF},   // mid-stream failure
}}
```

- Include failure verbs in every fake from day one: mid-stream error, context cancellation, slow-consumer backpressure (via injected clock, not real sleeps). A fake that can only succeed cannot express most bugs worth push-down.
- **Clock injection is mandatory** for anything with timeouts/retries. Pass a `Clock` interface; tests advance it manually. Never `time.Sleep` in T0.
- For concurrent state machines, cover **interleaving** nondeterminism too — property-based exploration of event orderings and race detectors — per the Determinism section of SKILL.md.

## T1 — protocol-level fake servers

A real listener on `localhost:0` speaking the provider's actual wire format; the production adapter connects to it via the rehome seam (base-URL config).

**Hand-built fake server** (scripted scenarios):

```go
srv := fakeprovider.Start(t)            // net/http or websocket server on :0
srv.Script(
    fakeprovider.AcceptHandshake(),
    fakeprovider.SendFrames(framesFromFile("testdata/greeting.jsonl")),
    fakeprovider.StallBeforeHeaders(15*time.Second),  // pathological behaviors are the point
)
adapter := realadapter.New(Config{BaseURL: srv.URL})  // PRODUCTION adapter, not a test double
```

Key properties:
- The **production adapter code path** is exercised end-to-end: serialization, framing, reconnect logic.
- Pathological behaviors are first-class script verbs: stall-before-headers, close-without-final-frame, half-close, garbage frame, oversized frame, out-of-order events, duplicate ids. Build the verb the first time a production bug needs it; keep it forever.
- Server per test, port :0, no shared state → parallel-safe and deterministic.

**Record-replay**:

1. **Capture**: recording mode in the adapter (env flag) writes every inbound/outbound frame with direction + monotonic offset to JSONL. Capture from a real T3 session.
2. **Sanitize**: strip `Authorization`, API keys, session tokens, PII. Grep the file for `key`, `token`, `Bearer`, `@` before committing. Commit under `testdata/recordings/<provider>/<date>-<scenario>.jsonl` with a header comment noting provider API version.
3. **Replay**: the fake server plays the recorded inbound frames; assert your pipeline's outputs. For request/response protocols, use an existing cassette library (go-vcr, vcrpy, Polly.js) instead of building one; for streaming/WS you usually need the bespoke JSONL harness.
4. **Timing**: replay frames as fast as possible by default (determinism); a separate mode honoring recorded inter-frame gaps only for latency-shape tests, and those use statistical assertions (below).

**When hand-built vs record-replay**: hand-built for behaviors you can specify ("server closes mid-stream"); record-replay for behaviors you observed but can't fully specify (provider's actual event ordering, undocumented fields). A provider-quirk bug pushed down from production should replay the *recorded pathological traffic*, not your reconstruction of it, whenever a capture exists.

**Multi-channel dependencies**: when a provider exposes multiple channels whose views must agree (e.g., a WS fill/event stream plus REST status polling — common for brokerages), the T1 fake must serve **all channels from one shared scripted state object**, so cross-channel skew and races (stream says filled, poll still says open; poll answers before the stream event arrives) are expressible as first-class script verbs. A standalone REST-cassette tool (wiremock/vcr) alongside an independent WS fake cannot express channel disagreement — use those only when the channels are genuinely independent.

## T2 — local substitutes

- **Local LLM**: point the LLM port's adapter (OpenAI-compatible API) at Ollama/llama.cpp/vLLM. See the **local-ai-stack** skill for serving setup. Pin the model + version in the ladder doc; assert on *structure* (valid JSON, tool-call shape, non-empty) not exact text.
- **Local STT/TTS**: whisper.cpp, Piper, etc. If no adequate local voice model exists, see **train-voice-models**.
- **Sandbox/paper endpoints**: exchanges and brokers ship them (paper trading, testnet). These are the *provider's own* T2 — high protocol fidelity, fake money. Treat sandbox drift as a known risk: sandboxes lag or lead production APIs; note the discrepancy list in the ladder doc.
- CI: T2 needs runners with model weights or sandbox creds. If PR runners can't, run T2 nightly and mark it advisory — do not silently skip it on PRs while reporting it as "in CI".
- **Fidelity honesty applies hardest here**: a green T2 run means *your pipeline* works. Never close a provider-quirk bug on T2 evidence alone.

## T3 — metered real-API smoke

Design constraints:

- **Small**: single-digit test count per provider. One happy-path streaming session, one auth check, one "the field we depend on still exists" schema assertion. It is a tripwire, not a suite.
- **Tagged**: build tag / pytest marker / test-name prefix so it never runs by accident. `go test -tags=metered`, `pytest -m metered`.
- **Budget-capped**: per-run cap enforced in the harness (count tokens/calls, abort over budget) and per-month cap on the API key itself where the provider supports it. Document both in the ladder doc. Where the tier can move real money or open positions, the cap must also be **provider-side risk limits** on the dedicated test account (max order size / notional / position limits), not just API spend.
- **Flaky policy, explicit**: 1 retry per test; on second failure, open/append an issue automatically rather than blocking anyone. T3 red must page a human eventually but must never block a merge on provider weather.
- Every assertion failure message includes: provider, model/API version, request id if available — T3 failures are debugged days later from logs.
- **Keep it alive**: a scheduled (nightly/weekly) trigger, not only manual. A T3 suite that only runs when someone remembers is a T3 suite that is broken and nobody knows.

## T4 — full E2E / prod-like

- Scheduled or pre-release. Uses seeded fixture entities (see below), never ad-hoc hand-created ones.
- Output must be triage-ready: on failure, collect server logs, session/call records, and artifacts into one place automatically — a T4 failure that requires manual log spelunking across services will be ignored.
- Bugs found here get pushed down (see push-down rule in SKILL.md). A T4 test's long-term job is catching *deployment/wiring* regressions only.

## Statistical latency assertions (T2+)

Never single-shot wall-clock asserts. Pattern:

```
runs = 20 (document why N)
measure per-run metric (e.g., first-audio-byte latency)
assert p95(runs) < threshold  # threshold from ladder doc, with provenance
print full distribution on failure, not just the p95
```

In T0/T1, latency logic (timeouts, deadlines) is tested with an injected clock — exact, deterministic, zero repetitions needed.

## Quarantine mechanics

- One file in-repo (e.g., `docs/testing-ladder.md#quarantine` or `testing/quarantine.yaml`): test name, tier, reason, owner, **expiry date**.
- CI reads it to skip-with-annotation (visibly skipped, not silently green).
- Expired entry = CI fails until the test is fixed or deleted. No expiry extension without a comment explaining what changed.
- T0/T1 tests are ineligible for quarantine — deterministic-tier flake means the test or the code is wrong; fix same day.

## Anti-patterns

- **Mock framework for streaming ports.** Call-expectation mocks (`expect(Recv).times(3)`) can't express "then the connection dies mid-frame". Failure: the exact bug class the ladder exists for is inexpressible at T0.
- **Fake server that speaks a cleaned-up version of the protocol.** You test against the protocol you wish the provider had. Failure: green T1, broken production. Cure: record-replay for anything you didn't personally specify.
- **T3 suite that grew to 40 tests.** It becomes slow, expensive, and flaky enough that people stop reading its failures. Push its logic tests down; keep the tripwire tiny.
- **Sleep-based synchronization anywhere.** Replace with event/channel waits or injected clocks. Every `sleep(2)` in a test is a future flake with your name on it.
