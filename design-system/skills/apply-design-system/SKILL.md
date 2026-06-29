---
name: apply-design-system
description: Audit a web UI against a reusable, token-driven design system and uplift it to a high polish bar. Use when the user wants to make a UI look better / more designed / less templated, apply a design system, fix inconsistent styling, establish design tokens, or match the quality of a reference app. Works with any stack (Svelte, Vue, React, plain CSS, Tailwind).
---

# Apply design system

Bring a web UI up to a high, consistent polish bar by giving it a **token-driven
foundation** (color, type, space, radius, elevation, motion) plus **class-and-token
component primitives** — then migrating the existing UI onto them. The foundation is
reusable across apps; only a small **brand layer** is tuned per app.

This skill ships its assets under the plugin root. Read them with the
`${CLAUDE_PLUGIN_ROOT}` variable (falls back to the `assets/` dir beside this
skill if the variable is unset):
- `${CLAUDE_PLUGIN_ROOT}/assets/tokens.template.css` — the tunable token foundation (start here)
- `${CLAUDE_PLUGIN_ROOT}/assets/primitives.css` — class-and-token component base
- `${CLAUDE_PLUGIN_ROOT}/assets/principles.md` — the 10-rule diagnostic checklist
- `${CLAUDE_PLUGIN_ROOT}/assets/reference-exemplar.md` — the gold-standard exemplar

> Read `principles.md` first — it's the rubric the whole audit runs against.

## When to use
- "make this look better / more polished / less default"
- "apply my design system" / "set up design tokens"
- "match the look of <reference app>"
- a UI with system fonts, flat panels, hardcoded hex/px, duplicated component styles.

## Workflow

### 1. Audit against the 10 principles
Locate the styling layer (global stylesheet, `:root` tokens, component styles,
`tailwind.config`, theme files). Score the UI against `principles.md`. Produce a
short findings list grouped **Critical / Major / Minor** (per the user's review
style — problems only, `file:line` + fix, no praise). The usual high-impact misses:
system fonts, no spacing/shadow scale, flat single-border panels, hardcoded
literals bypassing tokens, duplicated table/button/badge systems, missing states.

### 2. Decide the brand layer (and confirm with the user)
The foundation is fixed; per app you tune only:
- `--brand-hue`, `--brand-chroma`, `--neutral-hue` (the OKLCH accent + gray tint)
- `--font-sans` / `--font-mono` (the type pairing — the biggest single lever)
- default `data-theme` and `data-density`

Propose concrete values with a one-line rationale (e.g. "finance terminal →
hue 215 cyan, mono-forward, compact density, dark"). Don't ask an open "what do you
want?"; recommend, and let the user veto. If the app has an existing accent, map it
to the nearest OKLCH hue rather than inventing one.

### 3. Install the foundation
- Copy `tokens.template.css` into the project's styles dir (e.g. `tokens.css`) and
  set the brand knobs from step 2. Import it **first**, before any other CSS.
- Copy `primitives.css` in and import it **after** tokens.
- Set defaults on the root element: `<html data-theme="…" data-density="…">`.
- **Self-host the fonts** (don't depend on a runtime CDN for tokens/fonts — a CDN
  outage shouldn't break the look). Add `@font-face` or a bundled font package.

Adapt to the stack:
- **Plain CSS / Vue / Svelte**: import the two files globally; keep them as the
  single source of truth. Replace the old `:root` token block; map old token names
  to new ones so existing rules keep working during migration.
- **Tailwind**: translate the tokens into `theme.extend` (colors, fontFamily,
  borderRadius, boxShadow, spacing) so utilities resolve to the same values; keep
  `primitives.css` for the composite recipes (layered shadow, glass) that don't map
  cleanly to single utilities.

### 4. Migrate the UI onto tokens + primitives
- Replace hardcoded hex/px/shadow/font-size with the matching token.
- Collapse duplicated component styles into one primitive each (`.btn` + modifiers,
  one `.tbl`, one badge). Update call sites / framework components to emit the
  canonical classes. Variation = a modifier, never a fork.
- Give panels real elevation (`var(--shadow-2)`), inputs the focus ring, numbers the
  mono+tabular treatment, and every interactive element hover/focus/disabled states.
- Fix dead transitions and any malformed shorthand.
- If the project keeps a `COMPONENTS.md`, update it to list the canonical primitives.

### 5. Verify
- Run the app; screenshot key screens in both themes and at least one alt density.
- Re-check against `principles.md` — every Critical/Major from step 1 resolved.
- Confirm nothing regressed: no broken layouts, contrast ≥ 4.5:1, reduced-motion ok.
- Report what changed (`file:line`), before/after on the audit findings, and any
  follow-ups left.

## Guardrails
- **Token in, literal out.** If you type a hex or raw px during migration, stop and
  use/extend a token instead.
- **Don't redesign the product** — change the visual system, not the information
  architecture or features, unless the user asks.
- **One accent.** Resist adding decorative colors; semantics (good/warn/bad) are for
  meaning only.
- Prefer extending the foundation over patching one screen — a fix that only helps
  one page is a smell.
