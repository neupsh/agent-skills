# Reference exemplar

The gold-standard implementation this system generalizes from. A dark-first
"mission-control / broadcast HUD" aesthetic. Stack: Vue 3 + Vite + **vanilla CSS**,
one global `src/styles.css` (~2850 lines), **no Tailwind, no component library**.
Everything is class-and-token driven. Study it when you want a concrete target.

## What makes it read as high-craft

| Lever | How the exemplar does it |
|---|---|
| **Type** | Space Grotesk (UI, tight `-0.005em`→`-0.035em` tracking) + JetBrains Mono (IDs, URLs, cron, metrics, HUD micro-labels). `tabular-nums` on numerics. |
| **Color** | OKLCH 4-step bg ramp (blue-tinted neutrals, hue 240) + 4-step text ramp. **Two signal colors only:** teal `#48D7FE` for all signal/brand, red `#E0564B` for risk/critical. Nothing else. |
| **Elevation** | Layered card shadow: `inset 0 1px 0 highlight, 0 1px 2px contact, 0 14px 34px drop`. Accent elements add a teal glow `0 0 24px var(--accent-glow)`. |
| **Scales** | radius 8/12/16; density tokens (`compact`/`regular`/`spacious`) remap row-h, padding, gap AND font-size together via `[data-density]`. |
| **Glass** | overlays use `backdrop-filter: blur(28–32px) saturate(140%)` over semi-transparent OKLCH, with inset highlights + teal-tinted edge glow. |
| **Backdrop** | "stage aurora" — two radial teal gradients over `--bg-0` + a radial vignette behind a transparent floating topbar. |
| **HUD flourishes** | corner-bracket frames (`.corner.tl/.tr/...`), monospace micro-labels (`LINK SECURE`, `VER`) at `0.16em` tracking, animated "now line" on a timeline with a glowing dot head. |
| **States/motion** | `.12s` hover transitions; keyframes for pulse, modal-in (translateY+scale), slide-in, toast-pop, shimmer; `prefers-reduced-motion` respected. |
| **Theming** | full light/dark via `[data-theme]`; light mode pushes the accent darker for legibility on white and re-tints glass/shadow alpha. |
| **Discipline** | every primitive is single-class + modifier (`.btn` / `.btn.primary` / `.btn.ghost` / `.btn.sm`); Vue wrappers (`Btn.vue`, `Pill.vue`) just map props → those classes. |

## The token block (source values)
Brand teal `--accent: oklch(0.81 0.11 230)` (≈ `#48D7FE`), risk
`--bad: oklch(0.65 0.17 28)` (≈ `#E0564B`), neutral hue 240. These are exactly the
defaults baked into `tokens.template.css` — so the template **is** the exemplar's
foundation with the brand values turned into tunable knobs (`--brand-hue: 230`,
`--brand-chroma: 0.11`, `--neutral-hue: 240`). Change those three numbers and the
same machinery produces a different brand at the same quality bar.
