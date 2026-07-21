# engineering-skills

Reusable, harness-agnostic engineering skills. Each encodes staff/principal-engineer judgment as
executable guidance — decision rules, procedures, templates — so a capable-but-context-free agent
delivers senior-quality work without a senior in the loop.

These skills are **generic by design**: nothing project-specific lives here. Each consuming project
keeps a thin binding layer (its own project skill or `CLAUDE.md` section) with commands, costs,
fixture IDs, and seams. Every skill has a "Project binding" section stating what it expects.

## The roster

| Skill | What it encodes | Use when |
|-------|-----------------|----------|
| [`tech-lead`](skills/tech-lead/SKILL.md) | Running engineering work with a model hierarchy: strong model specs & reviews, mid model implements, small model does mechanical ops. Spec bar, decomposition, delegation templates, review gates. | Any non-trivial feature or initiative |
| [`autoship`](skills/autoship/SKILL.md) | Opt-in outer loop over an issue tracker: pull ticket(s), run `tech-lead` per ticket, merge, close, repeat. Strictly explicit-invocation only. | You say "autoship #123" and want tickets actually shipped |
| [`test-ladder`](skills/test-ladder/SKILL.md) | Cost-tiered testing for systems whose full-fidelity tests are expensive or flaky (paid AI/voice APIs, brokerage APIs, telephony, GPUs). Seam audits, the push-down rule, CI mapping, budget accounting. | Designing or fixing a test strategy where testing costs money |
| [`ports-and-modules`](skills/ports-and-modules/SKILL.md) | Strangler-style extraction of a modular core from a working monolith. Characterization tests, seam inventory, extraction ordering, module contracts. | Splitting a god file/service; making a platform pluggable |
| [`local-ai-stack`](skills/local-ai-stack/SKILL.md) | Free local substitutes for paid AI providers (Ollama, faster-whisper, Piper/Kokoro) wired through existing provider seams. What local can and cannot validate. | Making AI-dependent development cost $0 |
| [`train-voice-models`](skills/train-voice-models/SKILL.md) | Fine-tuning/distilling your own STT/TTS (especially low-resource languages) on free cloud GPU quotas. Eval-first milestones, checkpoint discipline, license-aware model selection. | Owning voice models instead of renting them |
| [`repo-truth`](skills/repo-truth/SKILL.md) | Auditing and maintaining agent-facing docs. Stale guidance is worse than none — agents follow it faithfully. | Onboarding a repo; after any doc/process drift |

The skills compose: `autoship` is the opt-in outer loop over a ticket queue, `tech-lead` the inner
loop per task; `test-ladder` + `ports-and-modules` shape what gets built; `local-ai-stack` +
`train-voice-models` are domain playbooks; `repo-truth` keeps the ground truth the others depend on.

## Recommended model-role mapping

The skills refer to abstract roles; bind them to whatever models you have.

| Role | Purpose | Claude default |
|------|---------|----------------|
| strong | Spec authoring, architecture, review, judging | Opus |
| mid | Implementation from a spec | Sonnet |
| small | Mechanical ops: commits, renames, formatting | Haiku |

## Other harnesses

Plain Markdown with YAML frontmatter — no Claude Code dependency. Paste or reference `SKILL.md`
into a rules file or system prompt, or tell the agent to read it before the matching work. The
`references/` files are progressive-disclosure depth — load them only when `SKILL.md` points at them.
