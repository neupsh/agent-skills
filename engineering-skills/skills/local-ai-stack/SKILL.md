---
name: local-ai-stack
description: Runs free local substitutes for paid AI providers (LLM, STT, TTS) so development and integration testing cost $0, wired through the app's existing provider seam. Use when a task needs repeated LLM/speech calls during dev or CI, when the user asks to avoid API spend, when tests are blocked because only paid credentials exist, or when standing up Ollama/Whisper/Piper-class services for an app that normally calls OpenAI/Anthropic/Deepgram/ElevenLabs-style APIs.
metadata:
  version: 1.0
---

# local-ai-stack

Substitute paid AI provider APIs with free, locally hosted equivalents for development and testing — without forking app logic. The core moves: (1) pick the right local substitute per modality, (2) wire it through the app's *existing* provider seam, (3) be honest about what the local stack can and cannot validate.

## When to use / when NOT to use

Use when:
- Dev or test loops make many LLM/STT/TTS calls and each call costs money (integration tests, eval loops, load tests, demo environments).
- You need to work offline or without credentials (CI without secrets, contributor machines).
- You are building the T2 "real components, fake providers" tier of a test ladder (see sibling skill **test-ladder**).

Do NOT use when:
- The task is a one-off manual check costing cents — setting up a local stack is more work than the spend it saves. Just call the real API once.
- The thing under test IS the provider: prompt quality, voice naturalness, provider-specific protocol quirks (streaming event ordering, vendor error codes), latency SLAs. Local substitutes cannot validate these — see "What the local stack validates" below.
- The app has no provider abstraction and adding one is out of scope for the current small task. Note the gap; don't bolt a local stack onto hardcoded vendor calls with `if local` branches.

## Project binding

Project-specific facts do NOT belong in this skill and must not be hardcoded from it. Look them up in the project repo — `CLAUDE.md`, a project-local skill, `docker-compose*.yml`, `justfile`/`Makefile`, or the config package:

- Which ports are reserved (many projects pin a port table — respect it; local AI services must not collide).
- The name of the provider seam (e.g. `LLMProvider` interface, `factory.Resolve*`, a `providers:` config block) and where base URLs are configured (env vars, settings DB, agent config).
- Which local models the project has standardized on, and where compose files for dev infra live.
- Existing start scripts (`dev_start.sh`, `just start`, etc.) — extend them; don't create a parallel startup path.

If the project has none of this documented, discover it with the audit in "Finding the seam", then record what you set up in the project's own docs (see sibling skill **repo-truth**).

## The substitution table

Verified 2026-07. Project names, image tags, and default ports churn — **re-verify with a quick web search before pinning anything in a compose file**, and date-stamp what you pin.

| Modality | Default substitute | API surface | Alternatives |
|---|---|---|---|
| LLM | **Ollama** — OpenAI-compatible at `http://localhost:11434/v1` (`/v1/chat/completions`, `/v1/models`) | OpenAI chat completions incl. streaming and (model-dependent) tool calls | vLLM (GPU, high-throughput, also OpenAI-compatible), llama.cpp `llama-server` (single-binary, OpenAI-compatible) |
| STT | **speaches** (formerly `faster-whisper-server`; repo `speaches-ai/speaches`) — faster-whisper behind `/v1/audio/transcriptions`, default port 8000 | OpenAI audio transcription incl. SSE streaming | whisper.cpp `server`; hand-rolled faster-whisper + FastAPI wrapper |
| TTS | **Kokoro-FastAPI** (repo `remsky/Kokoro-FastAPI`) — Kokoro-82M behind `/v1/audio/speech`, default port 8880; or **Piper** (fast, CPU-friendly) | OpenAI speech endpoint | speaches also serves TTS (Kokoro/Piper models) — a two-container stack (ollama + speaches) can cover all three modalities |
| Embeddings | Ollama `/v1/embeddings` with an embedding model (e.g. `nomic-embed-text`) | OpenAI embeddings | — |

Compose file, model-pull init, healthchecks, CPU/GPU variants, and bare-metal quickstarts: **read `references/docker-compose.md` when actually standing the stack up.**

## Integration rule: through the seam, never around it

**ALWAYS wire local services through the app's existing provider abstraction.** Two shapes:

1. **App already speaks an OpenAI-compatible API** (most common): configure `provider = "openai"` (or `"custom"`/`"local"` if the app has one) with a **base-URL override** pointing at the local service, and a dummy API key if the client requires one. Zero app-code changes.

   **The model identifier (and TTS voice) is part of the seam.** Many apps' provider config carries only `{provider, baseUrl, apiKey}` while call sites hardcode `model: "gpt-4"`, `"whisper-1"`, `"tts-1"` — those hardcoded ids 404 against Ollama/speaches/Kokoro regardless of the base-URL override. Widening the config object (or an adjacent env lookup used identically by local and real providers) to carry model/voice ids is in-scope seam work and is NOT an if-local fork; the test is that the same code path resolves both the real and local model ids from config.
2. **App speaks a vendor-specific protocol** (e.g. a Deepgram/ElevenLabs WebSocket): write a **thin adapter** that implements the app's provider interface (`STTProvider`, `TTSProvider`, whatever the repo calls it) and calls the local HTTP endpoint. The adapter lives next to the other provider implementations and is selected by the same factory/config mechanism that selects real providers.

**NEVER fork app logic with `if localMode` branches.** The failure: the local path and the real path drift, tests go green against code production never runs, and the branch metastasizes ("if local, skip retry logic", "if local, different chunk size"). If you catch yourself typing `if (env === 'local')` inside orchestration/business code, stop — that logic belongs behind the provider interface.

**If no seam exists, adding the seam is task #1** — before any local-stack work. A hardcoded `openai.NewClient(key)` call in the middle of a handler means the app can't select providers at all; extract an interface + factory first (see sibling skill **ports-and-modules** for the port/adapter shape, and **test-ladder** — this seam is exactly what makes the T2 tier possible).

### Finding the seam (audit procedure)

```bash
# 1. Vendor base URLs / SDK constructors — where do real providers get instantiated?
grep -rniE 'api\.openai\.com|api\.anthropic\.com|deepgram|elevenlabs|NewClient|baseURL|base_url' \
  --include='*.go' --include='*.ts' --include='*.py' -l | head -20

# 2. Config surface — is a base URL already configurable?
grep -rniE 'BASE_URL|endpoint|providers?:' -- '*.env.example' 'config*' 'settings*' 2>/dev/null

# 3. Provider interfaces / factory — how does the app choose a provider?
grep -rnE 'interface.*(Provider|Client)|(Provider|Client) interface|ABCMeta|Protocol\]?' --include='*.go' --include='*.py' --include='*.ts' | head
```

Decision: base URL already configurable → pure config change. Interface exists but base URL hardcoded → add the override field. No interface → seam-first task.

## Hardware honesty

Pick models for the machine you actually have, and calibrate latency expectations **before** debugging "slowness" — CPU inference latency is not an app bug.

| Tier | LLM | STT | TTS | Expect |
|---|---|---|---|---|
| CPU-only laptop (8-core, 16 GB) | 3B–8B quantized (q4): `qwen2.5:3b`, `llama3.2:3b`; 7–8B is the practical ceiling | whisper `small` int8 (`medium` if patient) | Piper (~10× realtime); Kokoro CPU ≈ 0.5–2× realtime | LLM ~5–20 tok/s, 0.5–2 s to first token; STT ~1–3× realtime; total voice-turn latency measured in seconds, not hundreds of ms |
| Consumer GPU (8 GB+ VRAM, RTX 3060+) | 7B–14B q4 comfortably; 30–80+ tok/s | whisper `small`/`medium`, many × realtime | Kokoro GPU, >10× realtime | Interactive latencies approaching hosted-provider feel |
| No GPU + big models | Don't. A 70B on CPU produces tokens slower than you read them; tests will time out and you'll misattribute it. |

Approximate resident memory (verified 2026-07; re-measure on your stack): 3B q4 LLM ≈ 2–3 GB, 7–8B q4 ≈ 5–6 GB, whisper `small` int8 ≈ 0.5–1 GB, Kokoro-82M ≈ 0.5 GB — plus a few hundred MB of per-container overhead. Rule of thumb for a 16 GB machine running the app under test alongside the stack: one 3B LLM + whisper small + one TTS engine fits comfortably; a 7–8B LLM fits only if the app itself is light. Use these numbers instead of inventing savings figures when choosing between stack variants.

Rule: **if a local run is slow, check this table before touching app code.** Conversely, if the app has latency-sensitive logic (voice barge-in, timeouts), either raise those timeouts via config for local runs, or accept that the local tier can't exercise timing behavior faithfully.

## What the local stack validates — and what it doesn't

The local stack validates **pipeline mechanics and integration logic**: message routing, session lifecycle, audio plumbing, retry/error paths (inject failures by stopping a container), tool-call orchestration flow, persistence, config resolution.

It does NOT validate:
- **Provider-specific protocol quirks** — vendor WebSocket event ordering, vendor error semantics, rate-limit behavior. The adapter you tested is not the adapter production runs.
- **Output quality** — small local LLMs reason worse and follow instructions worse; local TTS voices sound different; whisper `small` mishears things the paid model wouldn't. Never turn a local transcript/response mismatch into a "bug fix" in prompt or threshold logic.
- **Tool-calling reliability** — models under ~7B emit malformed function-call JSON with real frequency. If a test asserts tool-call correctness, use a tool-capable model (e.g. `qwen2.5:7b`+), constrain output with JSON-schema/format options where the server supports it, and design the test to tolerate an occasional retry — or move that assertion up a tier.

**Therefore: keep a small, metered real-API smoke tier.** A handful of tests against real providers with real credentials, run before release or on demand — not in every dev loop. This is the fidelity-honesty rule from sibling skill **test-ladder**: a green local run means "the plumbing works", never "the product works". Worked example: a voice platform whose only paid-API-free tier was unit mocks added ollama+speaches+kokoro as a T2 tier; integration bugs (sample-rate handling, barge-in state machine) surfaced locally for $0, while a 5-scenario real-provider smoke suite (~$0.50/run) stayed the release gate for protocol and quality behavior.

## Streaming and format caveats (audio pipelines)

- **Sample rates differ per engine**: Whisper resamples input to 16 kHz internally; Kokoro outputs 24 kHz; Piper voices are typically 16/22.05 kHz depending on voice quality tier. Paid providers often let you request an exact PCM rate — local servers may not. If the app assumes a provider-specific rate (telephony 8 kHz μ-law, `pcm_16000`…), resample in the adapter. **Symptom of getting this wrong: chipmunk or slow-motion audio, or STT returning garbage on perfectly good speech.** Check declared vs actual rate first.
- **Chunking/streaming shape differs**: local servers may return whole-utterance results where the paid provider streams partials, or chunk on different boundaries. Don't assert exact chunk counts/boundaries in local-tier tests; assert content and terminal state.
- **Response formats**: verify the local TTS supports the container/codec the app requests (wav/pcm vs mp3/opus); request `wav` or raw pcm for pipelines that parse audio.

## Health-check pattern

Verify each service **before** a dev/test session, and fail loudly with the fix command — a half-up stack produces confusing downstream errors (timeouts misread as app bugs). One-liners (adjust ports/paths to the project's binding):

```bash
curl -sf http://localhost:11434/v1/models >/dev/null \
  || { echo "LLM (ollama) DOWN — fix: docker compose -f <compose-path> up -d ollama"; exit 1; }
curl -sf http://localhost:8000/health >/dev/null \
  || { echo "STT (speaches) DOWN — fix: docker compose -f <compose-path> up -d speaches"; exit 1; }
curl -sf http://localhost:8880/health >/dev/null \
  || { echo "TTS (kokoro) DOWN — fix: docker compose -f <compose-path> up -d kokoro"; exit 1; }
```

Also verify the **model is pulled**, not just the server up — `curl -s http://localhost:11434/v1/models` must list the model the app is configured to use; an ollama with no models returns empty `data` and the app gets 404s. The same applies to speaches, which downloads whisper (and TTS) models **lazily**: a green `/health` does not mean the model is cached. Query its model-listing endpoint for the configured model id, or run one short transcription and treat a 30–120 s first call as "still downloading". This check is mandatory before any offline session. Put these checks in the project's dev-start script or a `just check-local-ai` target. A full round-trip smoke (TTS → STT → compare text) is in `references/docker-compose.md`.

## Offline use (no-connectivity sessions)

"Work offline" is a use-case this stack serves only with **pre-connectivity prep** — every lazy download must be forced while still connected:

1. **Prep checklist (while online)**: `docker compose pull`; run the ollama model-pull init service; warm speaches' lazily-downloaded whisper model with one real `/v1/audio/transcriptions` call; then run the full round-trip smoke once. **Do not start an offline session without one green smoke pass.**
2. **Offline recovery is restart-only**: `docker compose up -d <svc>` works offline when images and models are cached; `docker compose pull`, `ollama pull`, and speaches/HF lazy downloads do not. A model missing offline is unrecoverable — so health-check "fix:" messages used offline must say "restart cached container", never "pull".
3. Keep the two rituals distinct in the project's scripts: a pre-connectivity **prep** target and a per-session offline **check** target.

## License notes

Model and engine licenses differ between **internal dev use** (almost always fine) and **redistributing artifacts** (shipping models in images, generated audio in products) — check before shipping:

- Piper: original `rhasspy/piper` (MIT) archived Oct 2025; active development is `OHF-Voice/piper1-gpl` — **GPL-3.0**. Individual Piper voice models carry their own licenses too.
- Kokoro-82M weights: Apache-2.0 (as of 2026-07 — verify on the model card).
- Ollama-served models: license is per-model (Llama community license, Qwen Apache-2.0, etc.) — `ollama show <model>` displays it.
- Whisper weights: MIT; faster-whisper: MIT; speaches: check repo.

Rule: for dev/test on your own machines, proceed. Before baking any model into a shipped artifact or redistributing outputs commercially, read the specific model card — do not assume from the engine's license.

## Anti-patterns

- **If-local fork** — `if LOCAL_MODE` branches in app logic instead of a provider through the seam. Failure: local and prod paths drift; tests validate code production never executes.
- **Green-on-local quality claims** — declaring prompts/voice/accuracy "verified" from local-model output. Failure: ships regressions the real provider exposes immediately.
- **Silent slow** — filing latency "bugs" that are just CPU inference. Check the hardware table first.
- **Latest-tag drift** — unpinned `:latest` images; the stack breaks on a random morning. Pin tags, date-stamp them.
- **Chipmunk audio** — sample-rate mismatch between adapter and engine. Check rates before debugging the pipeline.
- **Hardcoded localhost** — base URLs embedded in code instead of flowing through the same config path real providers use. Failure: the "seam" silently becomes a fork.
- **Half-up stack** — skipping health checks; downstream timeout errors get misdiagnosed for an hour.

## Sibling skills

- **test-ladder** — where the local stack sits (T2: real components, fake providers) and the fidelity-honesty rule for the real-API smoke tier.
- **ports-and-modules** — how to add the provider seam when none exists.
- **repo-truth** — record the ports, models, and commands you set up in the project's own docs.
- **tech-lead** — scoping whether seam-first work belongs in the current task.
- **train-voice-models** — when local *inference* isn't enough and you need custom voices/models.
