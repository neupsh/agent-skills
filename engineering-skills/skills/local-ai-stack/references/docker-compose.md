# Local AI stack — compose file, quickstarts, smoke test

Component versions verified 2026-07. **Before pinning: re-check image tags and repo names with a web search** — these projects rename and re-tag (speaches was `faster-whisper-server`; Piper moved from `rhasspy/piper` to `OHF-Voice/piper1-gpl`). Pin explicit tags in real projects and note the date you pinned them. **If you cannot verify the current tag at write time** (offline, or no web tool available), do NOT invent a plausible-looking version number — leave an explicit `<PIN-ME: verify tag>` placeholder or keep `:latest` with a dated TODO comment. A guessed pin looks authoritative and breaks silently; an unresolved placeholder fails loudly.

## Port table (defaults — check the project's reserved-port list before adopting)

| Port | Service | Endpoint the app uses |
|---|---|---|
| 11434 | ollama (LLM) | `http://localhost:11434/v1/chat/completions`, `/v1/models`, `/v1/embeddings` |
| 8000 | speaches (STT, optional TTS) | `http://localhost:8000/v1/audio/transcriptions` |
| 8880 | Kokoro-FastAPI (TTS) | `http://localhost:8880/v1/audio/speech` |

If any of these collide with the project's own services, remap the **host** side only (`"18000:8000"`) and put the mapping in the project's docs.

## Canonical docker-compose.yml (CPU-only — works on any machine)

```yaml
# local-ai/docker-compose.yml — free local substitutes for paid AI providers.
# CPU-only by default; GPU overrides below. Pinned <DATE>; re-verify tags before reuse.
services:
  ollama:
    image: ollama/ollama:latest        # pin a version tag in real use
    ports: ["11434:11434"]
    volumes: [ollama-models:/root/.ollama]
    healthcheck:
      test: ["CMD", "ollama", "list"]  # image has no curl; ollama CLI works
      interval: 10s
      timeout: 5s
      retries: 12

  # One-shot init: pulls ONLY the models the app's config actually references, then exits.
  # The list below is an EXAMPLE — replace it with your app's configured models;
  # delete nomic-embed-text unless the app actually uses embeddings.
  ollama-pull:
    image: ollama/ollama:latest
    depends_on:
      ollama: { condition: service_healthy }
    environment:
      OLLAMA_HOST: http://ollama:11434
    entrypoint: >
      sh -c "ollama pull qwen2.5:3b && ollama pull nomic-embed-text"
    restart: "no"

  speaches:
    image: ghcr.io/speaches-ai/speaches:latest-cpu   # -cuda variant exists; verify tag
    ports: ["8000:8000"]
    volumes: [hf-cache:/home/ubuntu/.cache/huggingface]  # verify cache path for the tag you pin
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8000/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12

  kokoro:
    image: ghcr.io/remsky/kokoro-fastapi-cpu:latest  # kokoro-fastapi-gpu for NVIDIA; verify tag
    ports: ["8880:8880"]
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8880/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 12

volumes:
  ollama-models:
  hf-cache:
```

Notes:
- **Whisper model download is lazy** in speaches: the first `/v1/audio/transcriptions` call specifying e.g. `Systran/faster-whisper-small` triggers the download. Warm it once after `up` (see smoke test) so test runs don't eat the download latency.
- If a container's healthcheck fails because the image lacks `curl`, swap in `wget -qO-` or a python one-liner — check with `docker compose exec <svc> which curl`.
- Two-container minimal variant: speaches also serves **TTS** (Kokoro/Piper models) at `POST http://localhost:8000/v1/audio/speech` — `ollama` + `speaches` alone can cover LLM+STT+TTS if you don't need Kokoro-FastAPI's voice features. Fewer moving parts; prefer it unless the app needs both audio services concurrently under load. **Caveat:** the smoke test below is written for the Kokoro-FastAPI variant (`:8880`); speaches' TTS model/voice identifiers differ by release and are not pinned here. If you take the two-container variant, discover the TTS model/voice ids via speaches' model-listing endpoint **while you still have connectivity**, pin them in config with the date, and adapt step 2 of the smoke test to `:8000`.

## GPU overrides (NVIDIA)

Add to each service that should use the GPU (requires nvidia-container-toolkit on the host):

```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

And switch images: `ghcr.io/speaches-ai/speaches:latest-cuda`, `ghcr.io/remsky/kokoro-fastapi-gpu:latest`. Ollama's single image uses the GPU automatically when exposed. With a GPU, upgrade models: `qwen2.5:7b` (or larger) for tool-calling work, whisper `medium`.

## Bare-metal quickstarts (no Docker)

**Ollama**: `curl -fsSL https://ollama.com/install.sh | sh && ollama pull qwen2.5:3b` — serves on 11434 automatically.

**speaches**: designed for Docker; bare-metal is `uv`-based from the repo — follow its docs. If you only need STT and want minimal deps, a ~30-line FastAPI wrapper over `faster-whisper` exposing `/v1/audio/transcriptions` (multipart `file` + `model` fields, return `{"text": ...}`) is a legitimate adapter.

**Piper** (TTS, very fast on CPU): `pip install piper-tts`, then `python -m piper.http_server -m en_US-lessac-medium --port 5000`. **Caveat: this HTTP server is NOT OpenAI-compatible** (plain text-in/wav-out). Either front it with a tiny `/v1/audio/speech` adapter or use it only behind an app-side adapter implementing the project's TTS provider interface. License: active repo `OHF-Voice/piper1-gpl` is GPL-3.0 (the MIT `rhasspy/piper` is archived) — fine for dev use; check before redistribution.

## Wiring the app (recap)

Point the app's existing provider config at the local endpoints — never hardcode:

```
LLM:  provider=openai-compatible  base_url=http://localhost:11434/v1  model=qwen2.5:3b  api_key=local-dummy
STT:  provider=openai-compatible  base_url=http://localhost:8000/v1   model=Systran/faster-whisper-small
TTS:  provider=openai-compatible  base_url=http://localhost:8880/v1   model=kokoro  voice=af_heart
```

The exact config keys (env vars vs settings DB vs per-agent config) are project-specific — find them via the seam audit in SKILL.md and record them in the project docs.

## Round-trip smoke test

Run after `docker compose up -d --wait` to prove the whole stack, not just the ports. Also serves as the model-warm step.

```bash
#!/usr/bin/env bash
set -euo pipefail
FIX="fix: docker compose -f local-ai/docker-compose.yml up -d --wait"

# 1. LLM: model present and answering
curl -sf http://localhost:11434/v1/models | grep -q 'qwen2.5:3b' \
  || { echo "ollama up but model missing — run the ollama-pull service"; exit 1; }
curl -sf http://localhost:11434/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5:3b","messages":[{"role":"user","content":"Reply with exactly: pong"}]}' \
  | grep -qi pong || { echo "LLM completion failed — $FIX"; exit 1; }

# 2. TTS -> file (24 kHz wav from Kokoro)
curl -sf http://localhost:8880/v1/audio/speech \
  -H 'Content-Type: application/json' \
  -d '{"model":"kokoro","voice":"af_heart","input":"the quick brown fox","response_format":"wav"}' \
  -o /tmp/localai-smoke.wav || { echo "TTS failed — $FIX"; exit 1; }

# 3. STT the TTS output back; expect the phrase (tolerate minor mishearing on 'the')
curl -sf http://localhost:8000/v1/audio/transcriptions \
  -F file=@/tmp/localai-smoke.wav -F model=Systran/faster-whisper-small \
  | grep -qi 'quick brown fox' || { echo "STT round-trip failed — $FIX"; exit 1; }

echo "local AI stack: all healthy (LLM, TTS, STT round-trip)"
```

Failure-mode hints:
- TTS wav plays but STT returns junk → sample-rate/codec mismatch; confirm `response_format=wav` and that your app-side pipeline isn't reinterpreting 24 kHz as 16 kHz.
- First STT call takes 30–120 s → model download in progress (lazy pull); subsequent calls are fast. Run this smoke once after `up`, not inside every test.
- LLM returns malformed JSON when you ask for tool calls → expected on 3B models; upgrade to `qwen2.5:7b`+ or constrain with the server's JSON/format option (see SKILL.md tool-calling caveat).
