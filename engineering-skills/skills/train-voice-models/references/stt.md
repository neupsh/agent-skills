# STT Recipe: Fine-Tuning Whisper for a Low-Resource Language/Domain

## Base model

Start from OpenAI Whisper (MIT — code and weights; verified 2026-07) via HF `transformers` (`openai/whisper-small` / `-medium` / `-large-v3`). MIT means the fine-tuned result is yours to ship commercially. Distil-whisper checkpoints are also MIT.

Size ladder (params / fp16 VRAM ballpark): tiny 39M, base 74M, small 244M (~1 GB), medium 769M (~3 GB), large-v3 1.55B (~6 GB). With LoRA + int8/4-bit base loading, small and medium train comfortably on a single 16 GB T4; large-v3 LoRA fits but is slow — do it only after medium plateaus.

## Recipe outline

1. **Data** (see licenses below): assemble 10–100+ h of transcribed speech. For fine-tuning, 10–30 h of clean data already moves WER substantially on a language Whisper saw little of; more helps until quality, not quantity, is the binding constraint.
2. **Preprocess**: resample to 16 kHz mono; chunk/filter to 1–30 s (Whisper's window); attach normalized transcripts. Store as an HF `datasets` dataset (arrow/parquet) in persistent storage so sessions don't re-preprocess.
3. **Normalize text — script-aware, one function, used everywhere** (train targets, references, hypotheses):
   - Unicode NFC normalization first.
   - Numerals: pick ONE convention (native digits e.g. Devanagari ०१२ vs ASCII 0-9) and map everything to it.
   - Punctuation: decide whether sentence-final marks count (Devanagari danda `।`, double danda `॥`, Arabic `؟`, CJK `。`); standard practice is to strip punctuation for WER but keep it in training targets if the product needs punctuated output.
   - Collapse whitespace; strip zero-width joiners unless the script requires them.
   - For abugida scripts, report **CER alongside WER** — word boundaries are inconsistent across annotators and WER over-penalizes segmentation differences.
   - Commit the normalizer with unit tests (a table of raw → normalized pairs) per `repo-truth`.
4. **Train**: `Seq2SeqTrainer` + PEFT LoRA (r=16–32 on attention projections is a sane default), base model loaded 8-bit, fp16, gradient checkpointing on T4. Force the language/task tokens for a single-language model (`language=<xx>, task=transcribe`) — leaving Whisper's language detection active on a fine-tune is a classic silent-quality bug.
5. **Evaluate** with `jiwer` (or `evaluate`'s wer/cer) against the frozen dev set every `eval_steps`; final numbers on the untouched test set only.
6. **Merge + export**: merge LoRA into the base (`merge_and_unload`), then convert to CTranslate2 for faster-whisper serving:
   ```bash
   ct2-transformers-converter --model ./merged_model \
     --output_dir ./model-ct2 --quantization int8_float16 --copy_files tokenizer.json preprocessor_config.json
   ```
   Re-run the frozen test set through faster-whisper on the *converted* model and record any delta vs the HF checkpoint. Try `int8` (CPU) and `int8_float16` (GPU); if the delta exceeds noise, fall back to `float16`. Hand the artifact to `local-ai-stack`.

## Real-time / streaming serving

Whisper is a batch encoder-decoder — it has no native streaming mode. If the product interface is streaming with a first-token latency budget (e.g. a live voice agent needing first words <300–500 ms), batch RTF does not answer feasibility: you must serve via chunked inference with local agreement (whisper_streaming / faster-whisper chunking) or choose a natively streaming architecture, and **measure first-token latency in that serving shape on the target hardware (CPU vs GPU) during step-1 baselining — BEFORE training.** If no streaming shape of the candidate family meets the budget, the model family choice changes now, not after weeks of fine-tuning.

## Data sources for low-resource languages (verify availability per language)

| Source | License | Notes |
|---|---|---|
| Mozilla Common Voice | CC0 | Crowdsourced; hours vary wildly by language — check the per-language stats page. Quality-filter by vote counts. |
| OpenSLR corpora | per-corpus (many Apache-2.0/CC-BY-SA — read each `LICENSE`) | e.g., Nepali: SLR43 (high-quality TTS-grade, ~2k utterances, 18 female speakers) and SLR54 (large ASR set, ~157k utterances). Browse openslr.org for the target language. (verified 2026-07) |
| Google FLEURS | CC-BY | ~102 languages, ~10 h each; small but clean — often best reserved as dev/test, not train. |
| Own collection | yours | Scripted recordings or transcribed product audio (with consent/rights — see below). Often the only way to get domain vocabulary. |

Record the license of every corpus in its dataset card; CC-BY-SA training data can carry obligations — flag it to the user rather than deciding silently.

**Production audio: consent and PII.** Using production call/user recordings for training or eval requires all of: (1) the product ToS/customer DPA explicitly covering model training — "service improvement" or QA language is usually narrower and does not cover it; (2) call-recording/consent law for the callers' jurisdictions; (3) a PII-scrubbing pass before audio leaves org-controlled storage; (4) raw audio stays in org storage — push only model weights to third-party hubs, and verify HF repos are private before any push. (The consent note in tts.md covers only single-speaker voice talent; multi-party call audio is a different and harder consent shape.)

## Feasibility math (T4-class GPU, verified reference points 2026-07 — re-probe on your data)

Measure `sec_per_step` in a 10-minute probe before trusting any of this:

- **LoRA whisper-small**, batch 16 (grad-accum), ~20 h data: roughly 1–2 s/step; 3–5 epochs ≈ 5–15 GPU-hours. **Fits in one Kaggle week easily.**
- **LoRA whisper-medium**: ~2–3x small's step time; 15–30 GPU-hours. **Fits in one, at most two, weeks.**
- **LoRA whisper-large-v3**: 30–60+ GPU-hours. **Multi-week on free quota** — do only after medium plateaus below the bar.
- **Full fine-tune of medium/large**: does not fit 16 GB T4 sensibly, and the hour budget (100s of GPU-hours) does not fit weekly free quotas. If step-2/3 truly requires it, the honest options are multi-week LoRA at higher rank, distillation, or telling the user to rent burst compute (one-off credits from `free-gpu-logistics.md`).
- **Distillation (distil-whisper style)**: teacher pseudo-labeling of a large unlabeled corpus + training the shrunken student is typically 100+ GPU-hours plus the labeling passes — a burst-compute or multi-week project. Only worth it when quality is met and latency is the remaining gap.

## Common failure modes

- Language detection left on → model transcribes into the wrong language on quiet/ambiguous audio. Force the language token.
- Normalizer mismatch between training targets and eval references → WER numbers move for reasons unrelated to the model.
- Evaluating on training speakers (split not speaker-disjoint) → dev WER flattering, prod WER bad.
- Skipping the post-CTranslate2 re-eval → quantization regression ships silently.
- Measured batch RTF but the product needed streaming first-token latency → feasibility answered with the wrong number; see "Real-time / streaming serving" above.
