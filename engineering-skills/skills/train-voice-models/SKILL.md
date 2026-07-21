---
name: train-voice-models
description: Fine-tune or distill custom STT and TTS models for a target language or domain (especially low-resource languages) with no local GPU, using free cloud GPU quotas, and export the artifacts for local serving. Use when off-the-shelf speech models fail the quality bar for a language/domain, when asked to "train/fine-tune Whisper/a TTS voice", or when planning a custom-voice-model effort end to end (eval harness, data, training, export, A/B promotion).
metadata: {version: 1.0}
---

# Train Voice Models (STT + TTS) Without a Local GPU

Process skill for producing custom speech models: baseline first, fine-tune small, scale only when small plateaus, export for cheap serving, promote only after A/B. Assumes free preemptible cloud GPUs (Kaggle, Colab), so everything is built resumable.

## When to use / when NOT to use

Use when:
- An off-the-shelf STT/TTS model measurably fails the product's quality bar for a target language, accent, or domain vocabulary.
- You are planning or executing a fine-tune/distillation effort and need the milestone order, data pipeline, or free-GPU logistics.
- You must pick a TTS base model for a **commercial** product (license triage lives here).

Do NOT use when:
- Nobody has measured off-the-shelf performance yet — the first milestone below IS that measurement; do it before proposing any training.
- The gap is prompt/config-level (wrong language hint, wrong sample rate, missing vocabulary biasing). Fix config first; training is the last resort.
- The task is serving an existing model (that is `local-ai-stack`) or wiring provider APIs into an app (that is the project's own docs).
- A paid API already meets the bar and its cost fits the product economics — custom training is weeks of effort; don't start it to save trivial spend.

## Project binding

This skill is process-only. Project-specific facts live in the project repo (CLAUDE.md, a project skill, or `docs/`): target language and script, the quality bar (max WER/CER, latency budget, MOS floor), incumbent provider/model, serving constraints (CPU-only? edge? container size?), dataset locations, HF org/repo names, and eval-set paths. **Look them up there; never hardcode them from this skill.** If the project defines no quality bar, propose one and get the user to confirm before milestone 1 — "better" is not a bar. A sane default proposal: beat the best acceptably-licensed baseline by ≥15–20% relative WER/CER on the frozen production-condition eval set, without regressing the product latency/cost budget; or match the incumbent quality at materially lower cost/latency. Bring the user a number to react to, not an open question — non-expert stakeholders cannot pick a WER from nothing.

Sibling skills, where the project provides them: `local-ai-stack` (serving the exported artifact), `test-ladder` (where the A/B eval sits in the project's test tiers), `repo-truth` (where eval sets and configs must live), `tech-lead` (scoping/sequencing the effort), `ports-and-modules` (keeping the STT/TTS provider swappable behind an interface so a custom model is a drop-in). If a named skill does not exist in the environment, substitute the project's own equivalent: serving = the project's deployment docs; A/B tier = the project's cheapest end-to-end test that exercises real request paths; repo-truth = commit eval sets, manifests, and configs to the project repo.

## Volatile facts — verify before relying

Quotas, licenses, and model availability change. Facts below are **verified 2026-07**; re-verify with a web search anything older than ~3 months before building a plan on it. License verification is non-negotiable for commercial products (see TTS section).

## The milestone ladder (never skip step 1)

Each step has an exit criterion. Do not start step N+1 until step N's criterion is met and recorded.

### 1. Build the eval harness FIRST; baseline off-the-shelf models

Before any training code exists:

1. Assemble a held-out test set in the target language/domain: real or representative audio + reference transcripts (STT), reference texts (TTS). 30–60 min of audio / 100–300 utterances is a workable floor. Freeze it, version it, check it (or a pointer + hash) into the repo per `repo-truth`.
   **The eval set must match the production audio channel** — sample rate, codec, and noise conditions — not just the language. If production audio is telephony (8 kHz, codec artifacts, background noise) and only clean 16 kHz corpora are available, synthesize a degraded slice (downsample to 8 kHz, pass through a phone codec such as μ-law/AMR, add representative noise) and report it as a separate row next to the clean slice. The STOP rule and all promotion decisions are judged on the production-condition slice; a clean-speech WER does not predict production quality.
2. Write a scriptable evaluator: for STT, WER and CER (CER matters more for abugida/syllabic scripts where word segmentation is fuzzy) with a documented text normalizer; for TTS, round-trip intelligibility (synthesize → strong STT → WER vs input) plus a small human spot-check rubric.
3. Run every plausible off-the-shelf candidate through it and record a baseline table: model, WER/CER (or round-trip WER), RTF/latency on target hardware, license, cost. Candidate classes to enumerate explicitly: (a) raw base models at each size (e.g. whisper small/medium/large-v3), (b) the incumbent hosted provider(s) as wired in the product today, and (c) existing community fine-tunes for the target language — search HF Hub (e.g. "whisper <language>", multilingual projects like IndicWhisper) before writing any training code; a permissively-licensed published fine-tune that clears the bar fires the STOP rule for free. Each community checkpoint needs its own license check — it does not inherit the base model license.

**Exit criterion / STOP rule:** if any off-the-shelf model with an acceptable license meets the project's bar — STOP. Ship that via `local-ai-stack` and skip training entirely. The eval harness is still the deliverable; it becomes the regression gate.

Micro-example (illustrative numbers from one past project — never reuse them as your baselines; measure your own): a voice platform needed low-resource-language STT. Baselining showed whisper-large-v3 at 38% WER, whisper-medium at 52%, the paid incumbent at 31% — all above the 20% bar. That table justified training AND fixed the target ("beat 31% at ≤ large-v3 latency"). Without it, "fine-tune Whisper" has no definition of done.

### 2. Fine-tune small (LoRA/PEFT) and beat the baseline

- Start from the smallest base model that plausibly can meet the bar (STT: whisper-small or medium; TTS: the smallest permissive base). LoRA/PEFT, not full fine-tune.
- Train on free-GPU sessions using the checkpoint/resume discipline in `references/free-gpu-logistics.md`.
- Evaluate every checkpoint on the frozen dev set; final claim only on the untouched test set.

**Exit criterion:** fine-tuned small beats the best off-the-shelf baseline on the frozen test set. If it plateaus above the bar, only then consider a larger base.

### 3. Scale or distill for speed

- If quality is short: repeat step 2 on the next size up (feasibility math in `references/stt.md` — full FT of large models does not fit a weekly free quota; plan multi-week LoRA or rent burst compute).
- If quality is met but too slow: distill (distil-whisper approach — MIT, verified 2026-07: keep the encoder, shrink the decoder, train on pseudo-labels from the large teacher). Distillation needs much more unlabeled audio than fine-tuning; check data supply first.
- **The teacher must be a model you are licensed to distill from** — self-hosted open-weights (e.g. whisper-large-v3, MIT). Hosted STT APIs (Google, Deepgram, Azure, etc.) generally prohibit in their ToS using their output to train or improve another model; do NOT pseudo-label with the incumbent hosted provider, however convenient the existing integration makes it. Read the provider ToS before any pseudo-labeling.

### 4. Export for serving

- STT (Whisper family): convert to CTranslate2 int8 for faster-whisper serving; verify post-conversion WER on the same frozen set (quantization can cost accuracy — measure, don't assume).
- TTS: export ONNX where the runtime supports it (Piper-style VITS serves as ONNX on CPU).
- Publish the artifact with a model card: base model, data, license chain, eval numbers, export settings. Hand to `local-ai-stack` for serving.

### 5. A/B against the incumbent before promotion

Run the new model and the incumbent through the app's cheapest test tier that exercises real request paths (see `test-ladder`) on the same inputs. Promote only if the new model wins on the project's bar metrics without regressing latency/cost budgets. Record both results next to the model card. Keep the incumbent config one revert away.

## Data pipeline rules

- **Dataset card per dataset**: source, license, hours, speakers, collection method, known defects. No card, no training.
- **Splits frozen and versioned**: train/dev/test split once, by *speaker* (a speaker in test must not appear in train), commit the split manifest (file lists + hashes). Never re-split mid-project — every metric before and after becomes incomparable.
- **No test leakage**: grep your training manifest against the test manifest before every run: `comm -12 <(sort train.list) <(sort test.list)` must be empty. Public corpora overlap (FLEURS/Common Voice sentences recur); dedup on normalized transcript text too.
- **Quality filters before volume**: drop clips with clipping, wrong language, transcript/audio length ratio outliers, and duration outliers (<1s, >30s for Whisper). A smaller clean set beats a larger noisy one at fine-tune scale.
- **One normalizer, applied everywhere**: the same text normalization (numerals, punctuation, script-specific marks) must run on training targets, references, and hypotheses. A normalizer mismatch between train and eval silently inflates or deflates WER.

## Anti-patterns

- **Training-first**: writing a training loop before the eval harness exists. Failure: weeks of GPU time with no way to say whether the model improved, and no STOP check that would have shown off-the-shelf was already good enough.
- **Shifting-ground comparison**: comparing model A on test set v1 against model B on test set v2 (or different normalizers). Failure: promotion decisions based on noise; metrics that can't be reproduced.
- **Big-model-first**: burning the weekly quota on a large base before a small one has plateaued. Failure: quota exhausted at step 0.3 of an epoch, nothing learned about the data.
- **Ephemeral checkpoints**: saving checkpoints only to the session disk. Failure: a preempted 8-hour session loses 8 hours; happens repeatedly until discipline changes. Fix in `references/free-gpu-logistics.md`.
- **License-blind selection**: picking the best-sounding TTS (often a CPML/CC-BY-NC model) and building the product on it. Failure: entire voice stack must be replaced pre-launch; fine-tuning a non-commercial checkpoint does NOT launder the license (verified 2026-07: XTTS-v2 CPML is non-commercial with no one left to sell a license; F5-TTS official weights CC-BY-NC even after fine-tuning; MMS-TTS CC-BY-NC).
- **Unmeasured quantization**: shipping the int8/ONNX export on the assumption it matches the checkpoint. Failure: silent multi-point WER regression in prod.
- **"Better" as the goal**: starting without a numeric bar. Failure: no STOP rule, no promotion rule, open-ended project.
- **Production-channel-mismatched eval**: baselining and promoting on clean read speech when production is telephony/noisy audio. Failure: model looks great on the eval table, fails on real calls.
- **ToS-tainted pseudo-labels**: bootstrapping training data by auto-transcribing unlabeled audio with the incumbent hosted API. Failure: the entire trained model is legally tainted and must be discarded.

## References

- Read `references/free-gpu-logistics.md` when planning or running training sessions on Kaggle/Colab/other free GPUs: quotas (verified 2026-07), preemption discipline, checkpoint/resume pattern, session-bootstrap checklist.
- Read `references/stt.md` when fine-tuning speech-to-text: Whisper + LoRA recipe, datasets for low-resource languages, normalization for non-Latin scripts, feasibility math per quota, CTranslate2 export.
- Read `references/tts.md` when selecting or training text-to-speech: license-first model triage (verified 2026-07), dataset construction via scripted recording + forced alignment, round-trip evaluation.
