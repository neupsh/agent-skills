# Design system principles

The 10 rules that separate a *designed* UI from one that reads as templated. These
are the diagnostic checklist — most "this looks cheap" problems are a violation of
one of them. Ordered by impact-per-effort.

## 1. Type identity beats everything
The system font stack (`-apple-system, …`) is the single loudest "default" tell.
Load **one distinct display sans** for UI and **one real mono** for numbers, IDs,
metrics, code, timestamps. Tighten tracking on body (`-0.005em`) and headings
(`-0.02em`). Use `font-variant-numeric: tabular-nums` on every number so columns
align and digits don't jitter on update.

## 2. Tokens, never literals
Color, space, radius, shadow, font-size all come from CSS variables. A hardcoded
`#6366f1`, `0.75rem`, `border-radius: 8px`, or inline shadow is a bug — it drifts
from every sibling and breaks theming. If you're typing a hex or a raw px, you're
doing it wrong; add/extend a token instead.

## 3. One accent carries signal; semantics mean something
Pick **one** accent hue for all interactive/branded signal. Reserve good/warn/bad
for actual meaning (success, caution, risk) — never as decoration. A UI with five
"accent" colors looks like a ransom note. Restraint reads as confidence.

## 4. Elevation is layered, not a single border
Real surfaces use a 3-part shadow: **inset top highlight** (catches light) +
**tight contact shadow** + **soft ambient drop**. A flat `1px` border on a flat
fill is the #1 "cheap" tell. Give the eye depth so cards separate from canvas.

## 5. A scale for everything spatial
Space (4/8/12/16/24/32/48/64), radius (3 steps), font-size (a density-linked
ramp). Magic numbers (`0.6rem 1.5rem`, `13px`, `border-radius: 6px` next to a
`12px` sibling) destroy rhythm. Snap to the scale.

## 6. Derive, don't repeat
With OKLCH, the whole color ramp derives from a hue + chroma knob. Re-skinning is
two numbers, not a find-replace across 40 files. Same idea for components: one
`.btn` with `.primary`/`.ghost`/`.sm` modifiers — never `ButtonLarge` +
`ButtonPrimary` + a fourth padding block copy-pasted.

## 7. No duplicate systems
Four table styles, two badge systems, three segmented-control aliases — each copy
drifts and the inconsistency reads as sloppiness even when no single screen looks
bad. One canonical primitive per concept. Consolidate ruthlessly.

## 8. Motion is short, consistent, and reduced-motion safe
Transitions ~0.12–0.2s on one easing token. Hover/focus/active on every
interactive element. Honor `prefers-reduced-motion`. Never animate layout-shifting
properties where a transform would do. Broken/missing transitions feel dead.

## 9. Every state is designed
Hover, focus-visible, active, disabled, loading (skeleton/shimmer), empty, error.
A focus ring is `0 0 0 3px var(--accent-soft)`, not the browser default. Empty
states get a message, not a blank box. Unhandled states are where polish dies.

## 10. Self-contained, theme-aware, accessible
Styles travel with the component (scoped or token-driven), so it works dropped into
any page with just the import. Light/dark via `[data-theme]`. Contrast ≥ 4.5:1 for
text, touch targets ≥ 24px. A component that needs side-CSS to look right is broken.

---

### The smell test
Drop a component onto a blank page with only its import. If it looks finished —
right type, depth, spacing, states, both themes — the system is working. If it
needs page-level CSS to not look broken, fix the component, not the page.
