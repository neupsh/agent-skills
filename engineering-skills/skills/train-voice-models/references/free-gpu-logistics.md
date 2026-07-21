# Free-GPU Logistics: Training on Preemptible Free Sessions

Governing assumption: **every session can die in 5 minutes.** Anything you would lose on a kill is a bug in your setup, not bad luck. All numbers below verified 2026-07 — re-check with a web search before building a multi-week plan on them; providers change quotas without notice.

## Provider table (verified 2026-07)

| Provider | GPU | Quota | Session limit | Persistence | Notes |
|---|---|---|---|---|---|
| Kaggle Notebooks | T4 x2 or P100 (16 GB) | 30 h/week | 9 h max per GPU session (re-verified 2026-07) | Kaggle Datasets (private OK), `/kaggle/working` persists only on *committed* runs | Most predictable free option. T4 x2 and P100 draw from the same quota. Phone verification required for GPU/internet access. |
| Google Colab free | T4 (16 GB), not guaranteed | unpublished, observed ~15–30 h/week, dynamic | up to ~12 h, ~90 min idle timeout | Google Drive mount | Availability varies with demand and account history; treat as overflow, not primary. |
| Lightning AI Studios free | varies, interruptible | 15 credits/month (~small double-digit GPU-hours) | interruptible | persistent studio disk | Verify current credit-to-GPU-hour mapping before planning. |
| One-off credits (GCP $300/90d, RunPod ~$5–10, etc.) | various | one-time | n/a | provider storage | Good for a single large burst (e.g., a distillation run that doesn't fit weekly quotas). |

Decision rule: plan the *recurring* schedule around Kaggle (predictable quota); use Colab as same-day overflow; hold one-off credits for a burst step 3 needs. If total need exceeds ~30 h/week for many weeks, tell the user the free-tier plan is multi-month and let them decide whether to rent.

## The discipline that makes preemptible sessions viable

1. **Config-as-code in git.** The training script, hyperparameters (a YAML/JSON config, not notebook cells), normalizer, and eval code live in a git repo. The notebook is a thin launcher: clone, install, run. Never accumulate logic in notebook cells — a killed session loses uncommitted cells.
2. **Deterministic, resumable training script.** Seeded, and able to reconstruct its exact position (optimizer state, LR schedule, dataloader epoch/step) from a checkpoint. HF `Trainer`/`Seq2SeqTrainer` with `save_steps` + `resume_from_checkpoint` gives this for free — use it rather than hand-rolling.
3. **Checkpoint every N steps to storage that outlives the session.** Pick N so a kill costs ≤ ~20–30 min of compute (on a T4 fine-tune, typically every 200–500 steps). Destinations that work headless: HF Hub private model repo (`push_to_hub` or `huggingface_hub.upload_folder` in a callback — best option, versioned, resumable from anywhere), a Kaggle Dataset (update via `kaggle datasets version`), or Drive (Colab). Session `/tmp` and `/kaggle/working` on an *uncommitted* interactive run do NOT count.
4. **Resume-from-latest entrypoint.** `python train.py --config c.yaml --resume auto` must: find the newest checkpoint in persistent storage, download it, and continue — with zero human decisions. If resuming requires remembering which checkpoint was current, you will lose work.
5. **Log outside the session.** Metrics to CSV pushed with the checkpoint, or W&B free tier. The loss curve must survive the VM.
6. **Keep secrets out of notebooks.** HF/Kaggle/W&B tokens go in the provider's secrets manager (Kaggle "Secrets", Colab `userdata`), never in committed cells.

## Session-bootstrap checklist

Run at the top of every session (encode it as a single `bootstrap.sh` in the repo so it's one cell):

```bash
# 1. Verify GPU actually attached (free tiers sometimes give CPU-only)
nvidia-smi || { echo "NO GPU — abort, do not burn session time"; exit 1; }

# 2. Clone the training repo (pinned branch)
git clone --depth 1 -b main <repo-url> work && cd work

# 3. Install pinned deps (requirements.txt with versions, not 'pip install transformers')
pip install -r requirements.txt

# 4. Pull dataset from persistent storage (HF datasets / Kaggle Dataset attached as input)
python fetch_data.py --manifest data/train.list   # verifies hashes

# 5. Resume from latest checkpoint (no-op on first run)
python train.py --config configs/whisper_small_lora.yaml --resume auto \
  2>&1 | tee train.log &   # background it so the notebook cell isn't the process's lifeline
```

On Kaggle, prefer "Save & Run All (Commit)" for long runs — committed runs execute detached for the full session limit without a browser open. On Colab, keep the tab alive or accept the ~90 min idle timeout.

## End-of-session checklist

- Confirm the last checkpoint push succeeded (check the HF repo / dataset version timestamp, not the local log).
- Push metrics CSV.
- Note in the run log (a `runs.md` in the repo): session date, steps reached, dev WER at last eval, next action. The next session — possibly run by a different agent — starts from this note.

## Quota budgeting

Before starting, compute: `steps_needed × sec_per_step / 3600` vs weekly quota, with sec_per_step measured in a 10-minute probe run, not guessed. Write the math into the plan. If the answer is "6 weeks of full quota", that's a fact the user needs before you burn week 1. Feasibility reference points for STT are in `stt.md`.
