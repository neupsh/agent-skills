# Delegation: worked example, question-back protocol, parallel isolation

## Why the template is strict

A delegated implementer has **no access to your conversation, your spec document by reference, or your mental model**. Everything it needs must be IN the prompt: pasted contract, file paths with line refs, exact test commands. Every omitted section becomes a guess, and mid-model guesses on design questions are exactly the tokens the pipeline exists to avoid spending.

## Filled-in example

Task: slice 1 of the rate-limit spec in `spec-templates.md` (limiter package only — the handler wiring is slice 2, scheduled after because it depends on this interface existing and being reviewed).

```
## Task: In-memory per-org session limiter package

### Context
- Repo: /work/platform. Read these before starting:
  - pkg/types/org.go:12-40 — Org struct; you will add one field (see Contract).
  - pkg/store/orgs.go:20-35 — OrgLookup interface the limiter consumes; do not modify it.
  - pkg/limiter/ — does not exist yet; you create it.
- Relevant prior decision: limiter is in-memory single-instance by design;
  distributed limiting is explicitly out of scope (tracked separately).

### Contract
Add to Org struct: MaxConcurrentSessions int  (json/firestore tags matching
sibling fields; 0 = unlimited).

New package pkg/limiter:

    type SessionLimiter interface {
        // Acquire returns ErrLimitExceeded if the org is at capacity.
        // On success the caller MUST call release exactly once.
        Acquire(ctx context.Context, orgID string) (release func(), err error)
    }
    var ErrLimitExceeded = errors.New("session limit exceeded")
    func NewInMemoryLimiter(lookup OrgLookup) SessionLimiter

Semantics:
- MaxConcurrentSessions == 0 → Acquire always succeeds.
- Org lookup failure → return the lookup error; never fail open.
- release is idempotent (sync.Once); second call is a no-op.
- Concurrent Acquires at limit-1: exactly one succeeds (mutex, not atomics —
  simplicity over micro-perf here).

### Non-goals
- No HTTP handler changes (slice 2).
- No persistence of counts; process-local map is correct.
- No metrics/logging beyond returning errors.

### Done when
- These tests exist and pass:
  TestAcquire_UnderLimit_Succeeds, TestAcquire_AtLimit_ReturnsErrLimitExceeded,
  TestAcquire_ZeroLimit_Unlimited, TestRelease_Idempotent,
  TestAcquire_Race_ExactlyOneWins
- `go test -race ./pkg/limiter/...` green.
- `go test ./pkg/...` green (no regressions from the Org field).
- `git status` shows only: pkg/limiter/{limiter.go,limiter_test.go},
  pkg/types/org.go.

### Forbidden
- No new dependencies (stdlib only).
- No changes to OrgLookup or any existing interface.
- No drive-by refactors or reformatting of untouched code.
- No design decisions: if the Contract is ambiguous, STOP and ask.

### If blocked
Send back ONE question naming the specific decision and your two candidate
answers with a one-line tradeoff each. Format: "Decision needed: <X>.
Option A: <...> (tradeoff). Option B: <...> (tradeoff). I'd pick A unless
you object."
```

## The question-back protocol

**Good question-back** (targeted — costs one round-trip, resumes immediately):

> Decision needed: what should Acquire return when the org ID doesn't exist in the store? Option A: treat as lookup error, propagate store's ErrNotFound (fail closed, consistent with "never fail open"). Option B: treat as unlimited (fail open, avoids breaking sessions for orgs missing from a stale cache). I'd pick A unless you object.

The orchestrator answers in one line ("A — and add `TestAcquire_UnknownOrg_PropagatesNotFound`") and the slice resumes.

**Bad question-back** (broad — reject it, don't answer it):

> The spec doesn't cover error handling in detail. How should I handle the various failure modes?

Do not reply with a design discussion. A broad question-back is a signal the **spec** failed the zero-decisions bar. Response: fix the spec (add the error-strategy table rows), re-issue the task with the amended contract. Answering broadly in chat produces spec-by-implementation with extra steps — the decision exists only in a transcript the next agent will never see.

**Orchestrator answering rules:**
- Answer with a decision + any new done-criterion it implies. Nothing else.
- If the delegate's Option A/B framing reveals the spec had a hole, patch the spec file too, not just the chat — the spec is the artifact of record.
- Two question-backs from the same task = stop the task, re-review the spec.

## Parallel dispatch: the file-intersection audit

Before dispatching N slices in parallel:

1. For each slice, list its `Files to touch` (the spec has this; if it doesn't, the spec is not done).
2. Intersect pairwise. Any overlap →
   - **Merge** the two slices into one task if they're small or the overlap is the substance of both; or
   - **Isolate**: run each in its own worktree/branch (`git worktree add`), and schedule an explicit merge step you own. Budget for the merge — it is real work, not free.
3. Shared *read* dependencies (both slices read the same types file) are fine. Shared *writes* are never fine in the same tree.

Never dispatch two agents into the same file in the same working tree. Unlike a git merge conflict, same-tree concurrent edits produce **silent last-write-wins** — the loser's work vanishes with no diagnostic, and you discover it when tests that "passed" in the delegate's report fail in yours.

## Sequencing rules

- Riskiest slice first (novel API, unproven integration, perf question). If it fails, the spec changes while cheap.
- A slice that defines an interface consumed by another slice goes first, and gets reviewed before the consumer starts — otherwise the consumer builds against an interface the review is about to change.
- Everything else with disjoint files: parallel. Serializing independent slices "to be safe" buys nothing and multiplies wall-clock.

## Reviewing delegate output

- Run the delegate's stated test command yourself. Delegates report optimistically; some report "all green" on suites they never ran.
- Diff-audit for scope creep: `git diff --stat` — any file outside the task's `Files to touch` list is a finding, even if the change looks good. Revert or split it into its own reviewed task.
- Check the Forbidden list explicitly: lockfile diffs (new deps), public signature changes, reformat noise.
- Every warning from this review → tracked task before the next slice dispatches. No warning left floating.
