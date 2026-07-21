# TTS Recipe: License-First Selection, Dataset Building, Training, Evaluation

## License triage comes FIRST

For a commercial product, the model license decides before quality does. **Fine-tuning a non-commercial checkpoint does not change its license — the derivative inherits it.** Verify the license of the exact checkpoint (not just the repo's code license — they frequently differ) on the day you choose, and record source + date in the model card.

Snapshot, **verified 2026-07 — re-verify before relying**:

| Model | Code | Weights | Commercial? | Fine-tunable? |
|---|---|---|---|---|
| Piper (VITS) | original rhasspy/piper MIT but archived Oct 2025; maintained fork OHF-Voice/piper1-gpl is GPL-3.0 | per-voice, mostly permissive — check each voice card | Yes (GPL obligations apply if you ship the fork's code; pinned MIT archive avoids that) | Yes — established training recipe; exports ONNX, serves fast on CPU |
| Kokoro-82M | Apache-2.0 | Apache-2.0 | Yes | Community recipes exist (StyleTTS2-based, incl. new-language fine-tunes); less turnkey than Piper |
| StyleTTS 2 | MIT | check the specific checkpoint's training-data terms | Generally yes — verify checkpoint | Yes |
| F5-TTS | MIT | official checkpoints **CC-BY-NC** (Emilia data) — NC survives fine-tuning; Apache-2.0 reimplementation exists (OpenF5) but alpha/weaker | Official weights: NO | Yes, but the NC taint stays |
| MMS-TTS (Meta, 1100+ languages) | — | **CC-BY-NC-4.0** | NO | Yes (VITS arch) — useful as a research baseline only |
| XTTS-v2 (Coqui) | MPL-2.0 | **CPML — non-commercial**, and Coqui shut down Jan 2024 so no commercial license can be bought | NO — do not build a product on it | Irrelevant for commercial use |

Decision rule: for a commercial product shortlist only permissive-weights options (Piper/VITS, Kokoro, StyleTTS 2 with a clean checkpoint). Keep NC models (XTTS, F5 official, MMS) out of the product path entirely — including as "temporary" placeholders; temporary placeholders ship. They ARE legitimate as eval baselines to quantify the quality gap you must close.

## Dataset: what a voice needs

- **Single-speaker, clean, consistent**: 2–5 h gets an intelligible VITS/Piper voice; 10–20 h gets a good one. Consistent mic, room, distance, and speaking style across all recordings — inconsistency costs more quality than fewer hours.
- Recording spec: quiet room, 22.05 or 48 kHz WAV (downsample later per the model's spec), one utterance per file, no clipping (peak ≤ -3 dB).
- **Script selection**: phonetically balanced sentences in the target language, plus the product's domain phrases (numbers, currency, dates, names). 1500–3000 sentences ≈ 3–5 h.
- **Rights**: written consent from the voice talent covering commercial synthesis. No consent, no dataset.
- **Existing corpora**: some OpenSLR TTS-grade sets exist per language (e.g., high-quality multi-speaker female sets) — check openslr.org and each corpus license; multi-speaker data trains a multi-speaker model or seeds a base for single-speaker fine-tuning.

## Alignment and preprocessing

- Segment long recordings to utterances; verify each audio file matches its script line (spot-check with your STT model — a mismatched pair poisons training).
- Phoneme-based models (Piper/VITS) need a grapheme-to-phoneme path for the target language: espeak-ng language support is the usual gate — check the language is supported (or add rules) before committing to Piper.
- For building datasets from long-form audio: forced alignment with Montreal Forced Aligner (MFA) to get utterance boundaries; MFA needs an acoustic model + pronunciation dictionary for the language — for truly low-resource languages, budget time to train/adapt these or fall back to scripted per-utterance recording, which needs no alignment.
- Loudness-normalize (e.g., -23 LUFS), trim leading/trailing silence, resample to the model's expected rate.

## Training (free-GPU sessions per free-gpu-logistics.md)

- Piper/VITS fine-tune from an existing voice checkpoint (same or phonologically-near language) converges far faster than from scratch — hours-to-days on a T4, fits weekly free quota. From-scratch VITS is 100+ GPU-hours; avoid on free tier.
- Checkpoint to persistent storage every N steps; synthesize a fixed 10-sentence probe set at every eval checkpoint and store the WAVs — TTS loss curves are weak proxies, ears and round-trip WER are the signal.

## Evaluation

1. **Round-trip intelligibility (objective, automatable)**: synthesize the frozen test texts → transcribe with a strong STT (the best model from your STT baseline table, NOT the model you fine-tuned on this voice's data) → WER against the input text, using the same normalizer as the STT eval. Track it per checkpoint; it catches mispronunciations, dropped words, and collapse.
2. **Human spot check (subjective, small)**: 15–20 fixed sentences, 2–3 native listeners, 1–5 rating on naturalness + a defect checklist (wrong phoneme, robotic prosody, artifacts). Same sentences every round so scores are comparable.
3. **Latency/RTF on target serving hardware** (per `local-ai-stack` constraints) — a beautiful voice that misses the latency budget fails step 5 of the ladder.
4. Compare candidates on the SAME test texts and the same STT judge. Changing either invalidates the comparison.

## Export and handoff

Piper/VITS → ONNX (the Piper toolchain does this natively); verify the ONNX artifact's round-trip WER and RTF match the checkpoint before publishing. Model card must include: base model + license chain (base license, data licenses, talent consent), hours of data, eval numbers (round-trip WER, human scores), export settings. Then `local-ai-stack` for serving and step 5 (A/B) of the ladder.
