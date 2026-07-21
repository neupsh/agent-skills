---
name: autoship
description: Opt-in only — invoke ONLY when the user explicitly says "autoship" or otherwise explicitly asks you to work/fix/ship tickets yourself in this session (e.g. "autoship #123", "autoship these", "work ticket #123 and merge it", explicitly naming this skill). Never infer this mode from context, from a big backlog, or from a prior turn in the same conversation — each request needs its own explicit ask. The project default, absent that explicit ask, stays whatever the project normally does when it finds a bug/gap (typically: file a tracker issue and stop, per the project's own triage conventions) — do NOT autonomously implement+merge fixes just because you noticed something is wrong. When invoked, delivers ticket(s) end-to-end: spec, implement, review, merge, close — without waiting for a separate dispatch/label pipeline. Composes with tech-lead (per-ticket pipeline) and test-ladder (what tier of test each fix needs).
metadata: {version: 1.0}
---

# autoship

Ship the given ticket(s) to the trunk branch, fully, in this session. No hand-off, no re-labeling for
a separate agent/automation to pick up later, no stopping at "filed a plan." One ticket in, one merged
+ closed ticket out, repeated until the batch is done or you hit a real blocker.

This skill is the **outer loop over a ticket queue**; `tech-lead` is the **inner loop per ticket**
(intent → size gate → spec → delegate → review → verify → ship). Use them together: this skill decides
*which ticket, in what order, with what bookkeeping*; `tech-lead` decides *how to build this one thing
correctly*.

## When to use / when NOT to use

**Strictly opt-in.** Use only when the user explicitly asks, in the current turn, for tickets to be
worked/fixed/shipped by you directly — the word "autoship" itself, or an explicit ticket ID with a
delivery verb ("work ticket #123 and merge it", "fix these yourself"). A prior turn granting this doesn't carry
forward automatically; if it's unclear whether the current ask still wants this mode, ask, don't
assume.

**Do NOT use** — stay on the project's normal default instead (typically: file a tracker issue and
stop) — when: the user is just reporting a bug, asking a question, or discussing what's broken,
without asking you to fix it now; you noticed something wrong incidentally while doing other work;
the request is read-only triage/labeling; a single ticket already mid-flight in an active `tech-lead`
run (keep using `tech-lead`, don't re-wrap it); tickets explicitly gated on a human/operator action
you cannot perform. **Noticing a gap is not authorization to fix it end-to-end — that always needs
the explicit ask.**

## Project binding

This skill needs the following from the project (usually already declared in `CLAUDE.md`/`AGENTS.md`
— read it before starting; don't assume):

- **Issue tracker + CLI**: which tracker (GitHub Issues via `gh`, Linear, Jira, etc.) and how to
  read/comment/close a ticket. Default assumption below is `gh issue view/comment/close`; swap for
  whatever the project actually uses.
- **Branch + PR policy**: does feature/fix work go on a branch + PR, or direct-to-trunk? Any branch
  naming convention, commit message format (e.g. Conventional Commits), signing requirement (e.g. GPG
  `-S`), or attribution rule (e.g. no bot co-author footers)?
- **Review/merge gate**: is there an existing autonomous review→merge convention (independent
  reviewer subagent, human approval required, CI gate) — follow whatever's already standing rather
  than inventing a new one.
- **Agent/role roster**: does the project define named subagents (e.g. `architect`, `coder`,
  `reviewer`, `tester`) with a table of when to use each? If so, use that table. If not, fall back to
  the generic strong/mid/small role mapping from `tech-lead`.
- **Dispatch label(s) to avoid re-triggering**: if the project has an automated pipeline that also
  watches the tracker (e.g. a `ready-for-agent` label that triggers a separate bot), do not apply or
  rely on that label here — this skill means *you*, right now, are the agent working the ticket, not
  queuing it for something else to pick up.
- **Deploy/finish posture**: does the project have a standing rule about batching changes for a
  deploy window, or is it fine to merge continuously? Follow what's documented; don't assume either
  way.

If any of the above isn't discoverable from the repo's guidance files, ask once, up front, before
starting the batch — not per-ticket.

## Invocation

The user gives you one of:
- Explicit ticket ID(s): "autoship #348", "autoship #341 and #346"
- A loose description: "fix the two auth bugs", "handle whatever's open on the billing epic"
- Nothing specific ("keep going", "work whatever's next") — list open tickets and pick the smallest
  coherent set that's actually actionable now (not blocked on an operator action outside your
  control, a credential/secret only the user holds, or a gated external window).

Don't ask the user to confirm the plan before starting unless a ticket is genuinely ambiguous about
*what* to build (materially different implementations, per `tech-lead`'s intent-extraction rule) —
not *whether* to build it. Silence on smaller scope questions means: use judgment, note the
interpretation in the PR/commit description, proceed.

## Per-ticket loop

For each ticket, run `tech-lead`'s pipeline (size gate → spec if warranted → delegate → review →
verify) plus this tracker bookkeeping:

1. **Read the ticket.** Full body + comments + any linked tickets/PRs for context.
2. **Classify size** (per `tech-lead`): trivial/small tickets skip spec-authoring theater; anything
   with a real design decision (new data model, new interface boundary, new UI surface, cross-module
   architecture) gets a spec pass by the strong role first.
3. **Implement** on a branch (if the project uses branches) following its exact conventions: commit
   format, signing, attribution rules pulled from Project binding above. Never bypass a signing or
   hook requirement to force a commit through — stop and report if it fails.
4. **Green-gate it yourself, THEN review independently.** These are two jobs and they belong to two
   different agents.
   - **You** (the dispatcher) own the green gate, every round, before any reviewer is dispatched:
     build clean, full suite for the touched packages, linters, conflicts resolved, rebased on trunk.
     Never take an implementer's "all green" on trust — they report optimistically and they report it
     *wrongly* (an agent claiming "1015 passed" while seven tests were red is an observed failure, not
     a hypothetical). Catching that is yours, because you're the one who can act on it. Pass the
     verbatim output into the review prompt as established fact.
   - **The reviewer** does NOT rebuild or re-run the suite to confirm green — that duplicates a
     multi-minute job on every round and tells you nothing new. It reviews the diff, and where the risk
     warrants it verifies *empirically* with targeted commands: **fault-injection** (revert the fix, run
     the ONE test that covers it, confirm it goes RED, restore) and throwaway probes that try to break
     the change. A test that passes with *and* without the fix is worthless, and only running it reveals
     which kind you have.
   For anything touching money-moving, auth, data-integrity, or otherwise high-blast-radius code, treat
   this review as load-bearing: hold the merge on real correctness findings rather than rubber-stamping.
   Expect several rounds — a review that finds a critical is doing its job, not failing.
5. **Fix to approval.** Iterate implement↔review until approved. Don't merge on a "mostly fine, ship
   it" verdict if the reviewer flagged an actual bug.
6. **Merge** per the project's existing gate. Handle known-quirky merge tooling (e.g. a branch-delete
   step failing because another checkout holds the trunk branch, while the merge itself still
   succeeded) by verifying merge state directly rather than trusting a single command's exit code.
7. **Close the ticket**, or confirm it auto-closed via a merge-linked reference (e.g. `Closes #<n>`
   in the PR body). If it didn't auto-close, close it explicitly with a comment describing what
   shipped and how scope grew or narrowed vs. the original ask.
8. **New follow-ups found mid-fix**: if genuinely non-blocking and small, prefer fixing them in the
   same session (see Deploy/finish posture) over filing-and-deferring, unless you're rate-limited or
   it's out of the current batch's scope. Otherwise file a new ticket — don't silently drop it.

## Parallelism

Independent tickets (no shared files, no dependency between them) can run concurrently: dispatch
implementation subagents in isolated worktrees/branches so they don't collide on a shared checkout —
a shared, non-isolated worktree is a classic collision source (one agent's reset/checkout can wipe
another's in-progress edits). Review and merge can pipeline too: don't block ticket B's review on
ticket A's merge unless they touch overlapping code or one depends on the other.

## Deploy/finish posture (default, override per Project binding)

Absent a documented reason to batch, don't defer merged work waiting for a "safe deploy window" —
merge continuously and let deploys happen whenever the project owner chooses. The default throttle is
your own usage/rate limits, not deploy risk: if you hit those, stop, summarize what's merged vs. still
open, and let the user pick up from there.

## What this skill does NOT do

- Does not touch anything gated on an action only the user/operator can take (credential rotation,
  a coordinated external maintenance window, physical device auth) — flag those, don't attempt to
  route around them.
- Does not apply a separate automated-dispatch label/pipeline meant to hand the ticket to a *different*
  agent later — invoking this skill means the current session is doing the work now.
- Does not skip signing, tests, or an unresolved review finding, regardless of how minor the ticket
  looks.

## End-of-batch report

One summary: ticket → PR/commit → merged/closed status, any new follow-up tickets filed and why they
were deferred rather than fixed, and anything still blocked on the user. No trailing question unless
something is genuinely blocked.
