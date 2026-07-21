---
name: repo-truth
description: Audits and maintains agent-facing guidance (CLAUDE.md, AGENTS.md, READMEs, specs, status docs) so it never misleads. Use when guidance files contradict reality or each other, after a large merge/refactor that changed workflows, when onboarding into an unfamiliar repo whose docs smell stale, or when asked to "clean up / update the docs" — and as a definition-of-done check that a merged change updated affected guidance.
metadata: {version: 1.0}
---

# repo-truth — keep agent-facing guidance true

Framing fact: **for AI agents, stale guidance is worse than no guidance.** A human skims a wrong doc and gets suspicious; an agent faithfully executes the dead process, asserts the wrong status, or ports the obsolete convention into new code. Every guidance file is an instruction stream — treat a wrong one as a live bug, not a cosmetic issue.

## When to use / when NOT to use

Use when:
- A doc told you something that turned out false (command failed, dir missing, workflow doesn't match commits). Fix the doc in the same session — don't just route around it.
- Two guidance files describe the same process differently.
- You merged an initiative that changed how things are built, tested, run, or deployed.
- You're asked to audit, refresh, or consolidate documentation.

Do NOT use for:
- A typo or single wrong path — just fix it inline, no audit ceremony.
- API reference / user-facing product docs (different discipline; this skill is about *agent/contributor-facing process truth*).
- Repos you're doing a one-shot read-only task in — note the staleness in your report, don't launch a doc overhaul nobody asked for.

## The audit procedure (executable)

**1. Enumerate all guidance files.**

```bash
# Root-level and agent-facing guidance
ls CLAUDE.md AGENTS.md README* CONTRIBUTING* GEMINI.md 2>/dev/null
find . -maxdepth 1 -name '*.md' -not -path './node_modules/*'
find .claude .cursor .github openspec docs -name '*.md' 2>/dev/null | grep -v node_modules
# Nested instruction files (per-package CLAUDE.md / README)
git ls-files '*CLAUDE.md' '*AGENTS.md' '*/README.md'
```

**2. Spot-check 3 verifiable claims per file.** Pick claims an agent would act on, and verify against reality — not against other docs:
- Named paths/dirs exist: `ls <path>` for each directory or file the doc references.
- Named commands work: does the script/target exist? `grep -n '<target>' Makefile Justfile package.json` — dry-run if cheap.
- Described workflow matches the newest 10 commits: `git log --oneline -10 --stat` — if the doc says "all changes go through specs/" but the last 10 commits touch none, the doc and practice have diverged. Before acting, classify the claim: **DESCRIPTIVE** (asserts what exists/works — a command, a path, a dependency) → reality wins, fix the doc mechanically. **NORMATIVE** (asserts a required gate or policy — branch flow, review requirement, approval step) → the mismatch is ambiguous: either the doc is stale or the team is out of compliance. Never silently rewrite a normative doc to match observed practice (that ratifies a possible governance bypass) and never delete it; add a dated banner stating the observed divergence and escalate the decision to the repo owner.
- Status claims ("X is done", "Y is not supported") match the code: grep for the feature.

**3. Flag contradictions BETWEEN files.** Two documents describing the same process (how to deploy, how to run tests, how work gets approved) means at least one is dead. Find which by commit recency: `git log -1 --format='%ci' -- <file>` on each, then verify the newer one's claims. Never leave both standing.

**4. Classify every file: keep / update / delete / banner-and-escalate.** Banner-and-escalate is the mandatory verdict for false *normative* claims (step 2) — the file gets the dated divergence banner and the policy decision goes to the repo owner. Deliver the classification, then act on it (or list it for the user if the repo isn't yours to prune). Ship one audit's findings as one PR with one commit per file (conventional-commit style if the repo uses it); fixes land in the diff, escalation items appear as unchecked decision checkboxes in the PR body so the human decision is tracked where the evidence is.

## Rules

- **Single source of truth per topic.** One file owns "how to deploy"; every other mention is a one-line pointer to it. Duplicated instructions WILL drift — the copy nobody updates becomes the trap. A non-owning file (typically README) may carry at most the single entry-point command (e.g. the one command that starts the dev stack) plus a link to the owning doc, with an authority line. Multi-command lists (test tiers, deploy variants, seeding) live only in the owner — duplicating three commands "for convenience" recreates the twin-instructions drift.
- **Delete-or-date, same day.** A stale doc found during any work is either deleted or gets a dated banner at the very top *that day*:
  ```markdown
  > **STALE as of 2026-07-02:** superseded by `docs/deploy.md`. Kept only for the migration notes below.
  ```
  For the contested-policy case (false normative claim), use the escalation variant:
  ```markdown
  > **STALE as of 2026-07-02:** policy below does not match practice (0/50 recent commits followed it).
  > Owner decision needed: re-enforce or rewrite. Do not follow or codify either until resolved.
  ```
  No third option. "I'll fix it later" is how it stayed stale.
- **Guidance states its own authority order.** Every process doc says what wins on conflict: "If this contradicts CLAUDE.md, CLAUDE.md wins." An agent hitting a contradiction without an authority order must stop and ask; with one, it proceeds correctly.
- **Prefer deleting to archiving.** Git history is the archive. An `docs/archive/` directory is a stale-doc landfill that still gets grepped, still gets loaded into context, and still misleads. `git rm` it; anyone who needs it has `git log --follow`.
- **Fix the doc at the moment of discovery.** When a doc misleads you mid-task, the minimum viable fix (correct the line, or slap the STALE banner on) costs one minute. Deferring it guarantees the next agent hits the same trap. If the repo's own process gates changes behind proposals/specs/approvals, the minimum viable fix is always in scope immediately — a banner is an annotation, not a process change. Anything larger (restructuring a doc, deleting a file, changing a stated policy) follows the repo's change process like any other change.
- **Evidence goes in the commit/PR, never in the doc.** The verification trail (commands run, outputs, dates, greps) belongs in the commit message and PR body. The doc itself states only the current truth — no "verified via ls on <date>" asides and no "Removed <date>: this section described..." tombstones left in files. A tombstone is archiving-in-place: it becomes tomorrow's stale content and still gets loaded into agent context. The only dated text allowed inside a doc is the STALE banner on a file awaiting deletion or an owner decision.

## The fresh-agent smoke test

The pass condition for a repo's guidance: **an agent with zero context, reading only committed files, can find how to build, test, run, and deploy — and which process to follow — within 5 minutes.**

Run it literally: open CLAUDE.md/README cold and answer:
1. How do I build? How do I run tests (and which tiers exist)?
2. How do I run the app locally?
3. How do I deploy, and what's the approval/process gate?
4. What fixtures/IDs/seeds do integration tests need? (e.g., "the credentialed test agent is `<id>`", "seed with `<your seed command> <email>`")
5. Any environment quirks (ports that must not change, emulators, required env vars — names only, never values)?

If any answer lives in chat memory, a past conversation, or one person's head — **write it into the repo now**, in the file that owns that topic. Worked example (illustrative): a voice platform's eval suite silently failed for every fresh agent because "use fixture agent `agent-fixture-01` — it's the only one with provider credentials" existed only in one developer's session memory. One sentence in CLAUDE.md ended the recurring failure.

## Maintenance trigger

- **Every merged initiative updates affected guidance in the SAME PR.** This is a definition-of-done item (the `tech-lead` skill should enforce it in its done-checklist): if the change altered any build/test/run/deploy/process fact, the diff includes the doc edit. A follow-up "docs PR" is a euphemism for never.
- **After any doc audit, leave the repo with exactly one live process doc per topic.** Zero is a gap; two is a contradiction waiting to happen.
- Cheap heuristic between audits: when `git log --oneline -10` shows workflow-shaped changes (new CI file, deleted script, renamed service) with no `.md` in the same commits, guidance debt is accruing.

## Anti-patterns (named, with the failure they cause)

- **Aspirational docs** — describing the intended-but-unbuilt system in present tense ("Requests flow through the queue service"). Failure: agents write code against architecture that doesn't exist, and "verify against the docs" verifies against fiction. Fix: future work goes in a spec/proposal explicitly marked as not-yet-built; docs describe only what's merged. When you find present-tense prose for unbuilt work: if a matching spec/proposal already exists, replace the section with a one-line pointer explicitly marked "proposed, not built"; if none exists, delete the section and record in the PR body that the content was removed and a proposal is needed if the work is still wanted — do not author the proposal yourself to justify keeping the prose, and do not keep the prose "until someone decides".
- **Twin setup instructions** — README and CONTRIBUTING (or root and package-level docs) each carrying full setup steps. Failure: they drift; half of agents follow the dead one. Fix: one owner, the other becomes a link.
- **"Check with Sam" documentation** — a doc whose actual content is "ask <person>" or knowledge that only exists in a memory file / chat log. Failure: agents can't ask Sam; they guess. Fix: extract the fact into the repo (fresh-agent smoke test, item 4/5).
- **Sentimental retention** — keeping a wrong doc because deleting "loses information" or feels destructive. Failure: the wrong doc keeps getting loaded into agent context and outvotes the right one. Fix: delete-or-date; git history preserves everything.
- **Silent workaround** — you discover a doc is wrong, route around it, and finish your task. Failure: every subsequent agent rediscovers the trap at full cost. Fix: fix-at-discovery rule above.

## Project binding

This skill is generic. Project-specific facts — build/test/deploy commands, service ports, fixture IDs, seeding steps, environment quirks, which file is the source of truth for what — live in the project repo (CLAUDE.md, AGENTS.md, or a project-local skill). Look them up there; never hardcode them from this skill or from memory. If you find such a fact *missing* from the repo, that is itself a repo-truth finding: add it to the owning file.

## Sibling skills

- **tech-lead** — owns definition-of-done; the "update guidance in the same PR" rule should appear on its checklist.
- **test-ladder** — the source of truth for which test tiers exist; docs describing test strategy must match its ladder, and the fresh-agent smoke test's "which tiers exist" answer should point at it.
- **ports-and-modules** — architecture boundaries the docs describe; when auditing architecture claims, verify against its module map, not prose.
- **local-ai-stack** / **train-voice-models** — domain workflows whose run/seed/eval commands are exactly the kind of tribal knowledge the smoke test forces into the repo.
