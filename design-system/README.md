# design-system

A reusable, **token-driven design system** delivered as a Claude Code plugin. It
brings any web UI up to a high, consistent polish bar — the quality foundation that
makes apps look crafted instead of templated — with a small **brand layer** you tune
per app.

> The system generalizes a dark-first "mission-control / broadcast HUD" reference
> implementation: OKLCH color ramps, a real type pairing, layered elevation, scales
> for space/radius/shadow, density + light/dark theming, and class-and-token component
> primitives. The reference brand values are baked in as the template defaults; change
> three knobs to re-skin.

## What's inside

| File | Purpose |
|---|---|
| `skills/apply-design-system/SKILL.md` | The workflow: audit → tune brand → install → migrate → verify. Triggers on "make this look better", "apply my design system", etc. |
| `assets/tokens.template.css` | The tunable token foundation. Copy into a project, set the brand knobs. |
| `assets/primitives.css` | Class-and-token component base — controls (`.btn`, `.input`, `.pill`, `.tbl`, `.glass`…), the sidebar `.nav` + `.nav-item`, and a responsive `.app-shell` (`.grid-auto`, `.split`) that goes full-width on desktop, an icon rail on tablet, and a drawer on phone. |
| `assets/principles.md` | The 10-rule diagnostic checklist the audit runs against. |
| `assets/reference-exemplar.md` | The gold-standard exemplar, broken down. |

## Install

Add the marketplace, then install the plugin:

```
/plugin marketplace add neupsh/agent-skills
/plugin install design-system@agent-skills
```

Then in a target project just ask: *"apply my design system"*.

## The brand layer (tune these per app)

```css
:root {
  --brand-hue:    230;   /* accent hue — 230 teal, 265 indigo, 150 green … */
  --brand-chroma: 0.11;  /* 0.06 calm → 0.15 vivid */
  --neutral-hue:  240;   /* gray tint, keep within ~25° of brand-hue */
  --font-sans: 'Space Grotesk', …;
  --font-mono: 'JetBrains Mono', …;
}
```

Plus root defaults: `<html data-theme="dark|light" data-density="compact|regular|spacious">`.
Everything else re-derives. That's the whole point — same machinery, different brand,
same quality bar.

### Named brands (multiple skins, one system)
`tokens.template.css` ships two ready brands, each just re-pointing the three knobs —
**brand, theme and density are three independent axes**:

```html
<html data-brand="teal" data-theme="dark">     <!-- teal HUD (default)  -->
<html data-brand="indigo" data-theme="dark">   <!-- indigo/violet        -->
```

Add your own by copying the `[data-brand="…"]` block. The whole OKLCH ramp,
elevation, nav and aurora re-derive from the brand's hue/chroma — so two apps can
share one design system and still look like distinct products.

## Using it without the plugin
The two CSS files are framework-agnostic. Drop `tokens.template.css` then
`primitives.css` into any project (import tokens first), set the knobs, self-host the
fonts, and migrate component styles onto the tokens. For Tailwind, translate the
tokens into `theme.extend` and keep `primitives.css` for the composite recipes.
