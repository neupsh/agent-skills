---
name: tech-lead
description: Runs multi-step engineering work like a staff engineer orchestrating a model hierarchy — strong model authors specs and reviews, mid model implements from specs, small model does mechanical ops. Use when a task spans multiple files/slices, when delegating to subagents, or when a request needs intent extraction and a spec before code. Not for one-line fixes.
metadata: {version: 1.0}
---

# tech-lead

Run engineering work through a fixed pipeline with a hierarchy of models. The strong model (e.g. opus) spends tokens on **decisions**: intent, specs, decomposition, review. The mid model (e.g. sonnet) spends tokens on **well-specified execution**. The small model (e.g. haiku) does mechanical ops (commits, renames, formatting). If you catch the strong model doing mechanical edits, or the mid model making design calls, the pipeline is misconfigured — rebalance before continuing.

## When to use / when NOT to use

**Use** when: the change touches 3+ files or 2+ layers; you will delegate to subagents; the request is a feature, refactor, or behavior change with design decisions in it; two people could implement the request differently and both would claim they followed it.

**Do NOT use** (skip the ceremony, just do the work) for: typos, one-line fixes, dependency bumps, doc edits, renames, a change fully determined by an existing failing test. Spinning up spec→delegate→review for a one-liner is itself an anti-pattern (see **Ceremony inversion** below).

## The pipeline

```
Intent → Size gate → Spec → Decompose → Delegate → Review → Verify → Ship
```

Every stage gates the next. Never start coding while the spec is unreviewed; never ship while a review warning floats untracked.

## 0. Discover before you classify

In an unfamiliar repo, run a short read-only discovery pass before the size gate: project guidance files (CLAUDE.md, AGENTS.md, component inventory, task tracker), the dependency manifest (is the relevant SDK/library already present?), and any existing feature shaped like the request (`grep -ri <domain-term>`). This answers "net-new vs. augmenting" and loads the project-binding facts every later stage assumes.

**Never ask the user what the repo can answer.** Discoverable facts (which job queue, which test framework, whether an integration already exists) are resolved by exploration; the one question you may spend on the user (see Intent extraction) is reserved for decisions only they can make.

## 1. Size gate (proportionality)

Classify FIRST, before any spec work. Three sizes:

| Size | Heuristic | Process |
|------|-----------|---------|
| **Trivial** | ≤1 file, no design decision, reversible in one commit, outcome fully determined by the request (typo, rename, config value, obvious bug with a failing test) | Just do it. No spec, no delegation. |
| **Small** | 1–3 files, one seam, at most one design decision you can state and resolve inline | One-paragraph contract: goal, files, done-criteria, the one decision + your resolution. Then implement. |
| **Large** | 3+ files or 2+ layers (API + UI, schema + code), any migration, any public-interface change, anything you'd decompose into parallel tasks | Full spec (section 3), full pipeline. |

If unsure between two sizes, pick the smaller and be ready to upgrade the moment you hit an unplanned design decision. Upgrading mid-task is cheap; a full spec for a rename is pure waste.

## 2. Intent extraction

Before any work, restate the goal **behind** the request in one sentence. "Add a spinner" may mean "make the page feel responsive" — the fix might be optimistic UI, not a spinner.

Then enumerate what the user didn't say but will expect. Standard checklist:

- Auth/permissions on new endpoints or pages?
- Data migration for existing records?
- UI surface for the new backend capability (or is plumbing alone acceptable)?
- Tests — at what tier? (see sibling skill **test-ladder**)
- Docs, if behavior a user relies on changes?
- Error/empty/loading states, not just the happy path?

Decision rule: if two readings of the request diverge **materially** (different data model, different user-visible behavior, different scope by 2x), ask ONE crisp question offering both readings. Otherwise state your interpretation in one sentence and proceed — do not stall a clear task on hypothetical ambiguity.

> Example: "Let users export their data." Materially ambiguous: one-off CSV download button vs. scheduled export pipeline with delivery. Ask: "Export = on-demand CSV download from the UI, or recurring scheduled exports delivered externally? These need different designs." One question, two candidates, material difference. Ship the question, nothing else.

## 3. The spec bar

**A spec is done when the implementer needs ZERO design decisions.** That is the acceptance test for the spec itself. Read `references/spec-templates.md` when authoring a spec — it has full backend and UI templates with worked examples.

Minimum contents:

- **Backend spec**: data model fields + types; function/interface signatures (exact, compilable); error strategy (which errors, propagated or handled, what the caller sees); edge cases enumerated one per line; named test cases (name + scenario + expected outcome); files to touch.
- **UI spec**: exact components + props (by name, from the project's component inventory); layout structure; every interactive state — loading, error, empty, disabled, hover, focus; responsive behavior; where data comes from.
- **Explicitly deferred decisions**: a section listing each decision intentionally NOT made, with an owner ("defer to user", "resolve in follow-up task N"). A deferred decision with no owner is a spec bug — it will be resolved silently by the implementer, which is spec-by-implementation.
- **Domain-critical correctness classes get their own edge-case subsection.** If the domain has a well-known failure catalogue — money (decimal-vs-float, idempotency keys on financial calls, test/live credential isolation), auth (privilege escalation, session fixation), PII (logging, retention), concurrency (races, double-fires) — the spec enumerates that catalogue explicitly. A spec can meet the zero-decisions bar and still miss all of these if the author lacks domain instinct; the subsection forces the check.
- **External-service flows name their verification approach.** If the feature depends on a third-party service (webhooks, payment rails, provider APIs), the spec states how it will be exercised end-to-end without production traffic: the vendor's sandbox/test mode, CLI event triggering, a local mock server, or recorded replay (see sibling **test-ladder** for the tiering). "We'll test it in prod" is a spec bug.

Smell test: hand the spec to a different model with no conversation history. If it would come back with "should I…?", the spec is not done.

## 4. Decomposition

- **Slice vertically by seam, not horizontally by layer.** A slice = independently testable unit of user-visible or contract-visible behavior (endpoint + storage + its tests; component + its data hook). Never split as "task 1: all the models, task 2: all the handlers, task 3: all the UI" — no horizontal slice is testable alone, and integration errors surface only at the end. Seam choice follows the architecture's port boundaries — see sibling skill **ports-and-modules**.
- **Schedule the riskiest slice FIRST.** Risk = novel integration, unproven external API, performance question, anything where failure invalidates the plan. Fail fast while the spec is still cheap to change. Building the easy CRUD first and discovering in slice 4 that the core third-party API can't do what the spec assumed wastes every preceding slice.
- **Parallel slices must not share files.** Audit before dispatch: list files-to-touch per slice, intersect. If two slices share a file, either (a) merge them into one task, or (b) run them in isolated worktrees and plan the merge. Never dispatch two agents into the same file in the same tree — you get silent overwrites, not merge conflicts.
- Corollary: do not serialize slices that share nothing. Independent slices run in parallel; that is the point of decomposing.

## 5. Delegation

Every delegated task uses this template. Copy it verbatim and fill it in — every section, every time. An omitted "Forbidden" section is how you get a surprise dependency in the lockfile.

```
## Task: <one-line name>

### Context
- Repo: <path>. Read these before starting:
  - <file>:<line-range> — <why it matters>
  - <file> — <why it matters>
- Relevant prior decision: <one sentence or "none">

### Contract
<The spec slice this task implements: signatures, types, behavior.
Paste it — do not reference "the spec" by title; the implementer
has no access to this conversation.>

### Non-goals
- <adjacent thing NOT to build>
- <tempting refactor NOT to do>

### Done when
- <named test(s)> pass: `<exact test command>`
- <observable behavior, e.g. "GET /x returns 404 for missing id">
- No new files outside <dirs>; `git status` shows only intended changes.

### Forbidden
- No new dependencies.
- No changes to public APIs/interfaces other than those in the Contract.
- No drive-by refactors, reformatting of untouched code, or TODO cleanup.
- No design decisions: if the Contract is ambiguous, STOP and ask (protocol below).
- Secrets by NAME only: reference credentials as env-var/settings names
  (e.g. "reads STRIPE_WEBHOOK_SECRET from settings"), never values — in
  this prompt, in code, in logs, and in test output. Presence checks only.

### If blocked
Send back ONE question naming the specific decision and your two
candidate answers with a one-line tradeoff each. Never "what should
I do?" — that returns the design work to sender and stalls the slice.
Format: "Decision needed: <X>. Option A: <...> (tradeoff). Option B:
<...> (tradeoff). I'd pick A unless you object."
```

Read `references/delegation.md` for a fully worked filled-in example and the question-back protocol in depth.

Rules for the orchestrator side:

- Pass file paths + line refs in every prompt. A delegate that must rediscover context burns mid-model tokens on archaeology and guesses wrong.
- Answer a question-back with a decision, not a discussion. One targeted question gets one targeted answer; the slice resumes.
- If a delegate sends back a broad question, do not answer it broadly — that means the spec failed the zero-decisions bar. Fix the spec, re-issue the task.

## 6. Review gates

Four gates; each converts findings into tracked work before anything proceeds.

1. **Spec review — before any code starts.** Reviewer (strong model or the user) checks: zero open design decisions, edge cases enumerated, test cases named, deferred-decisions all have owners. Cheapest bugs to fix are the ones caught here.
2. **Green gate — YOU run it, before you dispatch any reviewer.** Never accept "tests pass" as a claim: implementer agents report success optimistically, and they report it wrongly (an agent reporting "1015 passed" while seven tests were red is a real, observed failure, not a hypothetical). But the *dispatcher* is the one who must catch that, not the reviewer. Before handing off, you personally: build clean (0 warnings), run the full suite for the touched packages, run the linter/formatter, resolve conflicts, and rebase onto the trunk. Then pass the **verbatim** command output into the review prompt as established fact.
   Why this belongs here and not in the review: a reviewer that re-verifies green duplicates a multi-minute build+suite you already ran, on every round — and review rounds are exactly when you least want a long feedback loop. One expensive verification per round, run by the one agent that can act on the result.
3. **Code review — correctness + intent-match, not style.** Linters own style; a reviewer commenting on formatting is wasting strong-model tokens. Check: does the code do what the spec says; does the spec-as-implemented still serve the extracted intent; are error paths real; did scope creep in.
   The reviewer **does not rebuild or re-run the suite to confirm green** — that is gate 2's job and it is already done. It **does** run *targeted* commands, and for anything high-blast-radius it must:
   - **Fault-inject**: revert the fix, run the ONE test that covers it, confirm it goes RED, restore. A test that passes with *and* without the fix is worthless, and only running it proves which. This is cheap (incremental compile, one test) and it is the highest-yield thing a reviewer does.
   - **Probe**: write a throwaway test that tries to *break* the change, and report the numbers.
   The distinction that matters: re-running the whole suite to confirm what you already know is waste; running one test to disprove a specific claim is the review.
4. **Warning conversion.** Every review warning — including "minor" and "consider" items — becomes a tracked task (in the task list / tasks file) before the pipeline proceeds. A warning acknowledged in chat and not written down is a warning lost. No warning left floating.

## 7. Verification and ship

Done requires ALL of:

- [ ] Tests green — full suite for the touched packages, not just the new tests. Never dismiss a failure as "pre-existing"; investigate or fix.
- [ ] **Changed flow driven end-to-end** — actually exercise the feature through its real entry point (HTTP call, UI click, CLI invocation), not just unit tests. Unit-green with a broken wire-up is the single most common false-done. Compose with sibling **test-ladder** for which tier suffices; if the flow needs local AI services or model endpoints, sibling **local-ai-stack** covers standing those up. For external-service flows, drive via the verification approach the spec named (vendor sandbox/test mode, CLI-triggered events, local mock) — confirm both the state change in your system and the corresponding artifact on the vendor's test dashboard where one exists.
- [ ] `git status` checked for untracked files — new files that were never added are the classic "shipped but broken in CI" failure.
- [ ] Behavior-affecting docs updated (README, API docs, changelog per project convention).
- [ ] Commit hygiene per project convention; mechanical commit work is small-model territory.

Only after this list: ship (commit/PR per the project's rules).

## Model economics

Strong-model tokens buy **judgment**: intent extraction, spec authorship, decomposition, review, resolving question-backs. Mid-model tokens buy **execution against a complete contract**. Small-model tokens buy **mechanical ops**.

Rebalance triggers:
- Strong model writing routine implementation code → the spec was good enough to delegate; delegate it.
- Mid model choosing data models, adding dependencies, or picking error strategies → the spec failed the bar; pull the decision up, fix the spec.
- Any model hand-editing 40 call sites → that's a small-model or scripted (sed/codemod) job.

## Anti-patterns (named)

| Anti-pattern | What it looks like | Failure it causes |
|---|---|---|
| **Spec-by-implementation** | Coder's incidental choices (a nullable field, a silent catch) become de-facto behavior nobody decided | Undocumented contract; the next change breaks "behavior" no spec ever promised |
| **The broad question-back** | Delegate returns "how should I handle errors here?" | Design work bounces back to sender; slice stalls; two models pay for one decision |
| **"Looks done"** | Accepting the implementer's success report without running tests or driving the flow | Broken wire-up ships; discovered by the user |
| **Implementer scope creep** | Delegate "also cleaned up" adjacent code, renamed things, added a helper dep | Unreviewable diff; regressions in code the spec never touched |
| **Serializing independent work** | Running non-overlapping slices one at a time "to be safe" | 3x wall-clock for zero risk reduction |
| **Parallelizing shared files** | Two agents dispatched into one file, same tree | Silent last-write-wins overwrites — worse than a merge conflict because nothing flags it |
| **Ceremony inversion** | Full spec + review pipeline for a typo; or "quick fix" treatment for a schema migration | Waste on one end; unreviewed risk on the other. The size gate exists to prevent both |
| **Floating warning** | "Good point, will keep in mind" — never written to the task list | The warning was the review's entire value; it evaporates |
| **Risk-last scheduling** | Easy CRUD slices first, novel integration last | Plan invalidated at 80% complete; all prior slices built on a false assumption |

## Project binding

This skill is generic. Project-specific facts live in the project repo — read them there; never hardcode or guess:

- **CLAUDE.md / project skills**: build + test commands, agent roster and model assignments, commit conventions, spec workflow tooling (e.g. an OpenSpec-style propose/apply flow — if the project has one, its flow supersedes this skill's spec format), deploy rules.
- **Component inventory** (e.g. `COMPONENTS.md`): UI specs must name components from it, not invent parallel ones.
- **Task tracking**: wherever the project tracks tasks (tasks.md, issue tracker) is where review warnings get converted.
- **Ground truth about repo state** — what's committed, branch rules, CI: see sibling skill **repo-truth** rather than assuming.

Sibling skills that compose with this one: **test-ladder** (which test tier a done-criterion needs), **ports-and-modules** (seam boundaries for decomposition), **repo-truth** (verifying repo/CI state before shipping), **local-ai-stack** (standing up local model services for end-to-end verification), **train-voice-models** (when the delegated work is model training rather than code). If a sibling skill is not installed in your environment, treat its name as a method label and apply this skill's own guidance — the core pipeline here is self-contained; siblings add depth, not prerequisites.

## References

- `references/spec-templates.md` — full backend + UI spec templates with a worked example each; read when authoring a Large-size spec.
- `references/delegation.md` — filled-in delegation prompt example, question-back protocol details, worktree isolation recipe; read before dispatching parallel delegates.
