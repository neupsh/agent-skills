# agent-skills

A Claude Code **plugin marketplace** — a home for reusable skills, plugins, hooks,
and agents.

> **Repo vs. marketplace name.** The repository is `neupsh/agent-skills`, but the
> marketplace identifier (what you type after `@`) is **`neupsh-skills`**. The name
> `agent-skills` is reserved for official `anthropics/` marketplaces, so plugins are
> installed as `<plugin>@neupsh-skills`.

## Use it

Add the marketplace, then install whichever plugins you want:

```
/plugin marketplace add neupsh/agent-skills
/plugin install design-system@neupsh-skills
/plugin install safety-hooks@neupsh-skills
```

### Wire it into your dotfiles

Add this to `settings.json` so the marketplace and your enabled plugins travel with
your dotfiles across machines:

```json
{
  "extraKnownMarketplaces": {
    "neupsh-skills": {
      "source": { "source": "github", "repo": "neupsh/agent-skills" }
    }
  },
  "enabledPlugins": {
    "design-system@neupsh-skills": true,
    "safety-hooks@neupsh-skills": true
  }
}
```

> **One-time bootstrap per machine.** `extraKnownMarketplaces` only marks the
> marketplace as *trusted* — it does **not** auto-clone on startup. On a fresh
> machine, run `/plugin marketplace add neupsh/agent-skills` once (it clones the repo
> into `~/.claude/plugins/`); after that the `enabledPlugins` entries resolve and
> install automatically. The repo is **public**, so the fetch needs no auth even
> before SSH keys are set up.

## Plugins

| Plugin | What it does |
|---|---|
| [`design-system`](./design-system) | Apply a reusable, token-driven design system to any web UI — OKLCH color ramps, type pairing, layered elevation, density + light/dark theming, and class-and-token component primitives. |
| [`safety-hooks`](./safety-hooks) | Defensive `PreToolUse` Bash guards — block `grep`/`find`/`rg`/`fd` searches against virtual filesystems (`/proc`, `/sys`, `/dev`) that can pin CPU for hours. |

### `design-system`

A token-driven design system delivered as a skill (`apply-design-system`). Ask
*"apply my design system"* in any project and it audits the UI, tunes a per-app brand
layer, installs the token foundation, and migrates components onto it. Provides:

- **`skills/apply-design-system/SKILL.md`** — the audit → tune → install → migrate →
  verify workflow.
- **`assets/tokens.template.css`** — the tunable token foundation (color/type/space/
  radius/elevation/motion), re-skinnable via three brand knobs.
- **`assets/primitives.css`** — class-and-token component base (`.btn`, `.input`,
  `.pill`, `.tbl`, `.glass`, `.nav`, a responsive `.app-shell`, …).
- **`assets/principles.md`** — the 10-rule diagnostic checklist the audit runs against.
- **`assets/reference-exemplar.md`** — a gold-standard implementation, broken down.

### `safety-hooks`

A `PreToolUse` hook (`block-proc-search.sh`) that runs before every Bash call and
**denies** `grep`/`ugrep`/`rg`/`ag`/`find`/`fd` commands targeting `/proc`, `/sys`, or
`/dev` — those can trigger infinite reads and pin CPU for hours. Everything else passes
through untouched. Wired automatically via `hooks/hooks.json` once enabled (no
`settings.json` editing). Requires `jq` on `PATH`.

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest (must be at repo ROOT)
design-system/                    # plugin: token-driven UI design system
  .claude-plugin/plugin.json
  skills/  assets/  README.md
safety-hooks/                     # plugin: defensive Bash PreToolUse guard
  .claude-plugin/plugin.json
  hooks/hooks.json
  scripts/block-proc-search.sh
  README.md
```

Each plugin is independently installable, so you can enable only what you need —
Claude Code toggles a plugin as a whole unit, which is why each concern is its own
plugin rather than one bundle.

## Notes

- **Statusline can't be shipped here.** Claude Code only honors `statusLine` from user
  `settings.json`; a plugin's bundled settings support only the `agent` and
  `subagentStatusLine` keys. Keep any custom statusline in your dotfiles.
- **Avoid double-loading when migrating.** If a hook or agent also exists under
  `~/.claude` (e.g. via dotfiles), remove the original after enabling the plugin —
  hooks from multiple sources combine (fire twice) and user-level agents shadow
  plugin agents.
