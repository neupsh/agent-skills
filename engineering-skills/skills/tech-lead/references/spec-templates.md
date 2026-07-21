# Spec templates

The acceptance test for any spec: **the implementer needs zero design decisions.** Hand it to a model with no conversation history; if it would ask "should I…?", the spec is not done.

Both templates end with an **Explicitly deferred decisions** table. Every row needs an owner. A deferred decision without an owner gets resolved silently by the implementer — that is spec-by-implementation, the exact failure specs exist to prevent.

---

## Backend spec template

```markdown
# Spec: <feature name>

## Intent
<One sentence: the goal behind the request, not the request itself.>

## Data model
<Every new/changed entity. Field, type, constraints, default. Exact — this
should be transcribable into the language's type syntax without choices.>

| Field | Type | Constraints | Default |
|-------|------|-------------|---------|

Migration: <required? backfill strategy for existing records? or "none — new collection/table">

## Interfaces
<Exact signatures — compilable in the project language. Include receiver/
module, param names, return types, error types.>

## Error strategy
<For each failure mode: is it propagated or handled here, what error type,
what does the caller/HTTP client see (status code + body shape)?>

| Failure | Handling | Caller sees |
|---------|----------|-------------|

## Edge cases
<One per line. Each must be covered by a test case below or explicitly
marked "accepted, not handled" with a reason.>

## Test cases
<Named. Name + scenario + expected outcome. These names become the
done-criteria in delegation prompts.>

- `Test<Name>_<Scenario>` — given <state>, when <action>, expect <outcome>.

## Files to touch
<Path + what changes in it. New files marked NEW.>

## Explicitly deferred decisions
| Decision | Why deferred | Owner |
|----------|-------------|-------|
```

### Worked example (genericized)

A voice platform needs per-organization rate limiting on session creation.

```markdown
# Spec: Per-org session rate limit

## Intent
Prevent a single org from exhausting shared realtime capacity; fail their
excess requests fast with a clear signal, without affecting other orgs.

## Data model
New fields on existing `Org` entity:

| Field | Type | Constraints | Default |
|-------|------|-------------|---------|
| MaxConcurrentSessions | int | >= 0; 0 = unlimited | 0 |

Migration: none — zero-value default means existing orgs are unlimited.
No backfill.

## Interfaces
    // pkg limiter
    type SessionLimiter interface {
        // Acquire returns ErrLimitExceeded if the org is at capacity.
        // On success the caller MUST call the returned release func
        // exactly once when the session ends.
        Acquire(ctx context.Context, orgID string) (release func(), err error)
    }
    func NewInMemoryLimiter(lookup OrgLookup) SessionLimiter

## Error strategy
| Failure | Handling | Caller sees |
|---------|----------|-------------|
| Org at limit | Propagate ErrLimitExceeded from Acquire | HTTP 429, body {"error":"session_limit_exceeded","limit":N} |
| Org lookup fails | Propagate; do NOT fail open | HTTP 500, generic error body |
| release() called twice | Second call is a no-op (guard with sync.Once) | n/a |

## Edge cases
- Limit lowered while org is over the new limit → existing sessions
  unaffected; only new Acquires rejected.
- Session ends via disconnect (no clean shutdown) → release must be
  deferred at the session-handler level, not the happy path only.
- Limit = 0 → unlimited (documented sentinel), NOT "block everything".
- Two Acquires race at limit-1 → exactly one succeeds (test with -race).

## Test cases
- `TestAcquire_UnderLimit_Succeeds` — limit 2, 1 active; Acquire succeeds.
- `TestAcquire_AtLimit_ReturnsErrLimitExceeded` — limit 2, 2 active.
- `TestAcquire_ZeroLimit_Unlimited` — limit 0, 100 Acquires all succeed.
- `TestRelease_Idempotent` — double release; count decremented once.
- `TestAcquire_Race_ExactlyOneWins` — limit 1, 2 concurrent; run -race.
- `TestHandler_LimitExceeded_Returns429WithLimit` — HTTP layer mapping.

## Files to touch
- pkg/limiter/limiter.go — NEW: interface + in-memory impl.
- pkg/limiter/limiter_test.go — NEW.
- pkg/types/org.go — add MaxConcurrentSessions field.
- services/gateway/internal/session/handler.go — Acquire before session
  start; defer release.
- services/api/internal/handler/org.go — expose field in org update API.

## Explicitly deferred decisions
| Decision | Why deferred | Owner |
|----------|-------------|-------|
| Distributed limiter (multi-instance gateway) | Single instance today; in-memory is correct until horizontal scale | Follow-up task; tracked in tasks file |
| Admin UI for setting the limit | Backend + API first; UI is a separate vertical slice | Slice 2 of this change (ux spec) |
```

Note what makes this pass the bar: the implementer never chooses a sentinel value, an error shape, a race semantics, or a fail-open/fail-closed posture — all decided.

---

## UI spec template

```markdown
# Spec: <feature name> (UI)

## Intent
<One sentence.>

## Components
<Exact component names + props FROM THE PROJECT'S COMPONENT INVENTORY
(COMPONENTS.md or equivalent). If a needed primitive doesn't exist,
the spec's first task is "add primitive X to the component library" —
never inline a raw HTML control.>

- `<Component prop1={...} prop2={...}>` — where used, why.

## Layout
<Structure as a nested outline or ASCII sketch. Container widths,
grid/flex arrangement, spacing scale tokens.>

## States — every interactive element gets all that apply
| Element | Loading | Error | Empty | Disabled | Hover/Focus |
|---------|---------|-------|-------|----------|-------------|

<No cell may read "default" — write what actually renders, e.g.
"skeleton row x3", "inline error text below field, field border
destructive color", "empty-state illustration + CTA button".>

## Data
<Which hook/endpoint feeds each region; what triggers refetch;
optimistic update or not (decide it here).>

## Responsive
<Breakpoint behavior. What collapses, what hides, what reflows.>

## Interactions & animation
<Click/submit flows, transitions with durations, keyboard behavior.>

## Files to touch
## Explicitly deferred decisions
| Decision | Why deferred | Owner |
```

### UI states — the checklist that catches missing spec work

For each interactive element ask: what renders while **loading**, on **error**, when **empty**, when **disabled**, on **hover/focus**? If the spec author can't answer one, that's a design decision being smuggled to the implementer. Most "the UI feels unfinished" complaints trace to states nobody specified.

---

## The one-paragraph contract (Small size)

For Small-size tasks, the full template is overkill. Use this shape, still written down before coding:

> **Contract:** <goal in one sentence>. Touch <files>. Done when <named test / observable behavior>. Decision made: <the one design decision + resolution>. Not doing: <the tempting adjacent thing>.

Example:
> **Contract:** Return 404 instead of 500 when an agent ID doesn't exist on GET /agents/:id. Touch handler/agent.go + its test. Done when `TestGetAgent_NotFound_404` passes and existing handler tests stay green. Decision made: distinguish not-found from store errors via errors.Is on the repo's ErrNotFound (already exists). Not doing: auditing other handlers for the same bug (separate task, filed).
