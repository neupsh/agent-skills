# Seam audit — full procedure

Goal: for every external dependency, know whether you can test against it at T0, T1, and T2 — and turn every gap into a filed, sized backlog item. Run this when entering an unfamiliar repo with paid/flaky externals, before large infra work, or when the push-down rule hits a wall ("no lower tier can express this bug").

## Step 1 — Enumerate external dependencies

Sources, in order:

1. Dependency manifests: `go.mod`, `package.json`, `pyproject.toml`, `Cargo.toml` — list vendor SDKs (provider names, `*-sdk`, `*-client` packages).
2. Config surface: grep env/config loading for URLs, keys, hosts. Do **not** read `.env` files themselves; read the code that consumes them.
3. Network call sites:

```bash
# HTTP/WS client construction:
grep -rn 'http\.Client\|http\.Get\|http\.Post\|websocket\.Dial\|fetch(\|axios\|requests\.\|httpx\.\|reqwest' \
  --include='*.go' --include='*.py' --include='*.ts' --include='*.rs' | grep -v _test
# Hardcoded external endpoints:
grep -rEn '"(https?|wss?)://[a-z0-9.-]+\.[a-z]{2,}' --include='*.go' --include='*.py' --include='*.ts' --include='*.rs' . | grep -v test | grep -v localhost
```

4. Infra: queues, databases-as-a-service, telephony webhooks, GPU job schedulers — anything the tests can't spin up trivially.

Deduplicate into a list of *dependencies* (e.g., "OpenAI chat completions", "Deepgram streaming STT", "Twilio voice", "exchange order API"), not call sites.

## Step 2 — Answer four questions per dependency

### Q1: Port exists?

Is there an interface/trait/protocol that business logic depends on, with the vendor SDK confined to an adapter?

```bash
# Find candidate ports (Go):
grep -rn 'type .*Provider interface\|type .*Client interface' --include='*.go'
# Rust:
rg -n 'trait\s+\w*(Provider|Client|Gateway|Feed|Stream)\w*' --type rust
# Python:
grep -rn 'class .*(Protocol\|ABC)' --include='*.py'
# TypeScript:
grep -rn 'interface \w*(Provider|Client|Gateway)' --include='*.ts'
# Find violations — vendor SDK imported outside adapter dirs:
grep -rln 'sdk-package-name' --include='*.go' | grep -v 'adapters/\|providers/\|_test'
```

Yes = business logic imports only the interface. Partial = interface exists but some code bypasses it (list the bypassing files). No = SDK calls inline in domain code.

### Q2: Fake injectable?

Can a test construct the system-under-test with a scripted fake, through the front door (constructor arg, DI container, factory param)? Monkeypatching/module-mocking does not count as "yes" — it couples tests to internals and breaks silently on refactor.

```bash
# Do constructors accept the interface or a concrete client?
grep -rn 'func New[A-Z].*(' --include='*.go' | grep -i 'provider\|client'       # Go
grep -rn 'fn new(' --include='*.rs' | grep -i 'provider\|client'                # Rust
grep -rn 'def __init__' --include='*.py' | grep -i 'provider\|client'           # Python
grep -rn 'constructor(' --include='*.ts' | grep -i 'provider\|client'           # TypeScript
# Do fakes/mocks already exist?
find . -path '*mock*' -o -path '*fake*' -name '*.go' -o -name '*fake*.py' -o -name '*fake*.rs' -o -name '*mock*.ts' | grep -v node_modules
rg -ln 'impl .* for .*Fake' --type rust   # Rust fakes implemented as trait impls
```

### Q3: Rehomeable? (real adapter → local base URL)

Can the *production adapter* be pointed at `http://localhost:PORT` via config? This is what unlocks T1 fake servers and T2 sandbox endpoints without code forking.

```bash
# Base URL configurable?
grep -rn 'BaseURL\|base_url\|baseUrl\|endpoint.*=.*env\|WithEndpoint' --include='*.go' --include='*.py' --include='*.ts' --include='*.rs' | grep -v _test
```

No = the adapter hardcodes the vendor host. Fix is usually a one-line config field — cheapest seam to add, do it opportunistically.

### Q4: Recorded traffic available?

Does the repo contain sanitized captures of real provider traffic (request/response pairs, streaming frame sequences) in a replayable format?

```bash
find . -path '*fixtures*' -o -path '*recordings*' -o -path '*cassettes*' -o -path '*testdata*' | head -30
```

Look for VCR cassettes (Python/Ruby), `go-vcr` fixtures, HAR files, or bespoke JSONL frame logs. "Some JSON blobs someone pasted once" counts as *partial* — undated, unversioned captures drift.

## Step 3 — Emit the seam table

| Dependency | Port? | Fake injectable? | Rehomeable? | Recorded traffic? | Backlog item |
|---|---|---|---|---|---|
| Hosted LLM (chat) | yes | yes | yes | partial (2024 captures, pre streaming-v2) | re-record streaming fixtures |
| Streaming STT | yes | yes | **no** — WS URL hardcoded | no | add base-URL config; build capture harness |
| Telephony | **no** — SDK inline in handlers | no | no | no | extract TelephonyPort (ports-and-modules); largest item |
| Sandbox exchange | yes | yes | yes (sandbox env) | n/a (sandbox is T2) | — |

Rules:

- **Every "no" is a backlog item** with a one-line fix description. File them (issue tracker or tasks doc) — do not leave the table as prose in a chat.
- Order the backlog by: (1) dependencies implicated in recent production bugs, (2) dependencies with the highest T3/T4 spend, (3) everything else.
- Put the table (or a link to it) in `docs/testing-ladder.md` under "Known gaps".

## Step 4 — Seam-fixing recipes (cheapest first)

1. **Rehome (Q3 no → yes):** add a base-URL/endpoint config field to the adapter, defaulting to the vendor host. Zero behavior change; unlocks T1/T2. Do this even in an otherwise unrelated PR touching the adapter.
2. **Injectable fake (Q2 no → yes):** change the constructor to accept the existing interface instead of constructing the SDK client internally; add a `NewXWithClient(port)` variant if the default constructor must stay.
3. **Extract port (Q1 no → yes):** structural work — read the **ports-and-modules** skill. Define the interface from *your code's usage*, not from the vendor's full API surface (a port with 40 methods you use 3 of is a fake-writing tax).
4. **Capture traffic (Q4 no → yes):** add a recording mode to the adapter (log frames/requests to JSONL behind an env flag), run one real session, sanitize (strip keys, tokens, PII — grep the capture for `key`, `token`, `Bearer`, emails before committing), commit under `testdata/recordings/` with a date and provider-API-version note.

## Anti-patterns

- **Auditing by memory.** "I think there's an interface for that" — run the greps; partial seams (interface exists, three call sites bypass it) are the common case and the dangerous one.
- **Port-per-vendor instead of port-per-capability.** `OpenAIPort` + `AnthropicPort` instead of `LLMPort` — you get a fake per vendor and no swap seam. Failure: T2 substitution requires code changes instead of config.
- **Marking Q4 "yes" for stale captures.** A 2-year-old cassette of a deprecated API version replays a protocol nobody speaks anymore; your T1 suite is green against a ghost. Date every capture; re-record when T3 smoke detects drift.
