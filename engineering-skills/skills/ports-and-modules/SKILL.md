---
name: ports-and-modules
description: Strangler-style extraction of a modular, pluggable core from a working monolith without stopping shipping — seam inventory, cheapest-first extraction order, module contracts, and channel/transport ports. Use when asked to "modularize", "make pluggable", "split the god loop/service", "add a second channel/provider/transport", or when a change keeps requiring edits to one giant component.
metadata: {version: 1.0}
---

# Ports and Modules: Strangling a Monolith While Shipping

Turn a working monolith into a modular core one shippable seam at a time. The monolith is an asset (it works, it has users, it encodes real behavior); treat every extraction as surgery on a live patient.

## When to use / when NOT to use

Use when:
- A "small" feature requires touching a 1000+ line component in 5 places.
- Adding a second provider/channel/transport means copy-pasting a switch statement.
- The team wants "plugins" or "modules" but the codebase has one god struct/config/loop.
- You're asked to add capability B and notice capability A is trapped in the wrong runtime.

Do NOT use when:
- The task is a bug fix, rename, or single feature that fits the current structure. Ship it as-is; note the seam friction in a follow-up issue.
- There is exactly one implementation of a concept and no concrete second use on the roadmap. A port with one implementation and no test fake is premature (see Interface Discipline below).
- The system is pre-product-market-fit throwaway code. Modularity tax on code that may be deleted is waste.

Proportionality: extracting one interface param is a 20-minute PR — just do it inside the feature branch that needs it (separate commit). Splitting a god loop is a multi-PR campaign — get buy-in, write the seam inventory first.

## Prime directive

**Never refactor and change behavior in the same PR.** Every PR is either "behavior identical, structure better" or "structure identical, behavior changed" — reviewers cannot verify both at once, and a regression in a mixed PR is undiagnosable.

Before touching a god component, **lock current behavior with characterization tests**: tests that assert what the code DOES, not what it should do. If the current code returns an empty string on a nil input, the characterization test asserts empty string — even if that's arguably a bug. Fix the bug later, in its own PR, by changing the test first.

Procedure and templates: read `references/characterization-tests.md` before your first extraction from any untested component.

## Seam inventory (run this audit first)

Before proposing any split, spend one pass cataloging the seams that already exist and where they're violated. Full executable procedure with grep patterns per language: read `references/seam-inventory.md`. The five things to find:

1. **Existing interfaces that are bypassed.** The repo often already has `Provider`/`Repository`/`Transport` interfaces — find call sites that reach around them to the concrete type.
2. **Concrete-type leaks.** Constructors/functions taking `*ConcretePostgresStore` where a `Store` interface exists. Widening the param is a one-line fix with outsized value: it makes the caller testable with a fake.
3. **Duplicated switch statements.** The same `switch providerType` in two files = a missing interface or registry. Two copies WILL drift (someone adds a case to one and not the other).
4. **Hardcoded enum dispatch that should be a registration map.** `switch kind { case "email": ...; case "sms": ... }` in shared code means every new kind edits core files. Replace with `map[Kind]Handler` populated explicitly in main.
5. **Capabilities trapped in one runtime.** Logic that is semantically domain-level living inside one channel's loop — e.g. "mark conversation resolved" or "create ticket" implemented inside a voice-call loop when text chat needs it too. These are the highest-value extractions: the capability is already written, it's just imprisoned.

Output of the audit: a ranked list (cheapest first) of seams, each with the files involved and the interface that would fix it. This list IS your extraction roadmap.

## Extraction order heuristic (cheapest-first, each step shippable)

Do these in order. Each step is independently mergeable with green tests; stop at any point and the codebase is strictly better.

1. **Widen concrete params to existing interfaces.** `func New(s *PgStore)` → `func New(s Store)`. Zero behavior risk, immediately unlocks fakes in tests. Batch several in one PR only if they're mechanical.
2. **Extract pure logic (no I/O) into core packages.** Parsing, validation, state-machine transitions, prompt/message assembly. Pure functions move with trivial tests and no mocking. Grep the god component for functions that never touch a client, socket, or DB handle — those move first.
3. **Split god loops by responsibility with the SMALLEST stable interface between the halves.** Example: a conversational engine tangled with audio streaming splits into a *turn engine* (domain: takes user input, produces assistant output + actions) and a *speech shell* (transport: STT in, TTS out, interruption handling). The interface between them is 3–5 methods, not 20. If you're designing a 20-method interface, you cut in the wrong place — find the waist of the hourglass.
4. **Replace duplicated dispatch switches with registries.** `map[Type]Handler` + explicit `registry.Register("email", emailHandler)` calls in main. Never `init()`-magic or blank-import side effects — registration must be greppable and visible in one place.
5. **Split monolithic config/domain structs into per-module sections with per-module validation.** A 40-field `Config` where each module reads 5 fields becomes `Config{Voice VoiceConfig, Tickets TicketConfig, ...}`, each with its own `Validate()`. A module owns its config schema; core owns only composition.

Micro-example of step 3's payoff: a voice platform where the only test tier free of paid APIs was unit mocks. After splitting turn engine from speech shell, the entire conversation logic ran in tests against a fake channel — no audio, no provider keys, sub-second suite. That test-cost collapse, not aesthetics, is the business case you cite.

## Module contract

A module is not "a folder". Define it as the tuple:

- **Config schema + validation** it owns
- **Capabilities/tools** it contributes (things the core can invoke)
- **Routes/UI** it registers
- **Adapters** it provides (implementations of core ports)
- **Permissions** it needs (declared, not assumed)

Registration is **explicit in main** (or a composition root): `app.Register(tickets.Module(cfg.Tickets))`. No magic `init()` discovery, no classpath scanning, no side-effect imports — when a module misbehaves you must be able to answer "who wired this in?" with one grep.

Full template (interface + example implementation + composition-root wiring): read `references/module-contract.md` when you're defining the first module boundary.

## Channel/transport abstraction (conversational and session systems)

If the system handles conversations/sessions over multiple transports (voice, text chat, survey, API, SMS...), the core engine sees only a minimal **Channel port**:

- receive input (with speaker/turn metadata)
- emit output
- signal end / interruption
- channel metadata (identity, capabilities like "supports audio", "supports rich cards")

Voice, text, survey, API are **adapters** implementing that port. Two hard rules:

- **Records and sessions are channel-neutral.** One `Session`/`Conversation` type with per-channel extension fields (`ChannelData map[string]any` or typed optional sections). **Never fork the record type per channel** (`VoiceSession` vs `ChatSession`) — every query, report, retention policy, and admin screen would fork with it, forever.
- **Capabilities live in the core, not the channel.** "Mark resolved", "escalate", "create ticket" are domain actions any channel can trigger. If one lives inside a channel loop, extraction step 2/3 pulls it out.

Channel port template: in `references/module-contract.md`.

### Where side effects execute

In a core/shell split, place effects by whether the core's consistency depends on them:

- **Core-invoked ports** — writes that must commit atomically with the domain decision (persisting an order, placing an inventory hold). The core calls `Store.Save` inside the operation, never defers it to the adapter.
- **Returned actions** — fire-and-forget effects a second adapter might legitimately suppress, batch, or reroute (notifications, emails, metrics) may instead be returned as channel-neutral action/event descriptors that the adapter executes.

Decision rule: If deferring the effect to the caller could leave the domain state inconsistent, it is a port the core calls; if a second adapter could correctly choose not to perform it, it is a returned action.

## Strangler sequencing

- **One seam per PR.** Green tests at every merge. If a seam can't be done in one reviewable PR, it needs an intermediate seam first.
- **The riskiest extraction runs behind a flag or in shadow.** New path behind a feature flag, or dual-write/shadow mode (new path runs alongside, results compared, old path's output used). Pick shadow mode when you can compare outputs cheaply; pick a flag when you can't. Shadow mode is cheap for stateless request/response and batch paths; for stateful interactive sessions (WebSocket loops, live calls), live diffing is expensive and side effects can double-fire — prefer a feature flag plus replayed/golden session recordings instead.
- **Every parallel-path setup gets an explicit kill date.** "We'll delete the old path once we're confident" is how systems end up with two payment paths for three years. Write the deletion as a tracked task with a date at the moment you create the second path — not as an intention.
- **Track old-path deletion as a task, not an intention.** When the kill date arrives, deletion is the task; extending the date requires stating why.

## Interface design discipline

- **Extract interfaces from the SECOND concrete use, not speculatively from the first.** The first implementation teaches you the shape; the second tells you which parts are actually common. An interface guessed from one use is almost always wrong in the methods it includes. A committed second consumer that is the very feature motivating the extraction (e.g., the REST/batch API you are about to build) counts as the second concrete use — shape the port from both consumers now; only a hypothetical future consumer is speculative.
- Exception: a test fake counts as a second use. If you need to fake it in tests *today*, extract today.
- **A port with one implementation and no test fake is premature.** Delete it or inline it — it's indirection tax with no payout.
- Keep ports **consumer-defined and minimal**: the interface lives with (and is shaped by) the code that calls it, not the code that implements it. If the turn engine needs 3 methods of a 12-method channel, it depends on a 3-method interface.

## Anti-patterns (named, with the failure they cause)

- **Big-Bang Rewrite** — "we'll build v2 clean alongside." Fails because the monolith keeps changing while v2 chases it; v2 ships late with fewer features and new bugs. Strangle instead.
- **While-I'm-Here** — behavior tweaks slipped into a refactor PR. Fails because when the regression appears, git bisect lands on a 2000-line "refactor" and nobody can separate the intentional change from the accident.
- **Speculative Plugin Framework** — building a module system before the second module exists. Fails because the framework's abstractions are guessed, so module #2 doesn't fit and you rewrite the framework anyway — having paid for it twice.
- **Both-Paths-Alive-Forever** — flag/shadow path with no kill date. Fails as doubled test matrix, doubled bug surface, and eventually nobody remembers which path is live.
- **Extract-by-Layer** — "first all repos, then all services, then all handlers." Fails because no slice is ever finished; you carry a half-migrated codebase for months with zero shipped value. Extract by **capability slice** instead: one capability's repo + service + handler + tests moves together and is DONE.
- **Fork-the-Record-Type** — per-channel/per-variant copies of a domain record. Fails as N-way drift in every query and screen that touches it.

## Definition of done per extraction

An extraction PR (or short PR series) is done when ALL of:

- [ ] Old callers are gone, or their deletion is a dated tracked task.
- [ ] Tests moved WITH the code (a package with its tests left behind in the monolith isn't extracted).
- [ ] Characterization tests still green, unmodified.
- [ ] No new circular deps (`go list`/`madge`/import-linter clean — see references/seam-inventory.md for commands).
- [ ] Guidance docs updated: architecture notes, module list, CLAUDE.md pointers. Cross-ref the **repo-truth** skill if present in your environment; otherwise just verify docs match the new structure — docs that lie about structure are worse than none.
- [ ] The seam inventory list is updated (item checked off, any newly discovered seams appended).

## Project binding

This skill is generic. Project-specific facts — build/test commands, package paths, module registries, composition-root location, flag systems, deploy gates, cost constraints on test tiers — live in the project repo: CLAUDE.md, a project skill, or `docs/architecture`. **Look them up there; never hardcode them from memory.** If the project has no documented composition root or module list, creating one is part of your first extraction's definition of done.

## Sibling skills

If these skills are not installed in your environment, ignore the references — this skill is self-contained.

- **tech-lead** — sequencing a multi-PR campaign, getting buy-in, scoping what NOT to do.
- **test-ladder** — where characterization and post-extraction tests sit in the test-tier hierarchy; the "cheapest tier that can catch it" rule.
- **repo-truth** — keeping architecture docs/CLAUDE.md honest after each extraction; consult before writing the DoD docs update.
- **local-ai-stack** — when the extraction's payoff is running the core against local/fake AI providers instead of paid APIs.
- **train-voice-models** — only relevant if the channel adapters you're extracting include custom speech models.
