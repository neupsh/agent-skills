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
/plugin install engineering-skills@neupsh-skills
/plugin install personal-ops@neupsh-skills
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
    "safety-hooks@neupsh-skills": true,
    "engineering-skills@neupsh-skills": true,
    "personal-ops@neupsh-skills": true
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
| [`engineering-skills`](./engineering-skills) | Seven harness-agnostic engineering skills encoding staff-engineer judgment — `tech-lead`, `autoship`, `test-ladder`, `ports-and-modules`, `local-ai-stack`, `train-voice-models`, `repo-truth`. |
| [`personal-ops`](./personal-ops) | High-stakes personal admin where being verifiably right beats being fast. Currently `amend-tax-return`. |

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
engineering-skills/               # plugin: harness-agnostic engineering skills
  .claude-plugin/plugin.json
  skills/<name>/SKILL.md (+ references/)
  README.md
personal-ops/                     # plugin: high-stakes personal admin
  .claude-plugin/plugin.json
  skills/<name>/SKILL.md (+ references/)
  README.md
```

Each plugin is independently installable, so you can enable only what you need —
Claude Code toggles a plugin as a whole unit, which is why each concern is its own
plugin rather than one bundle.

## No personal data — hard rule

**This repo is public.** Nothing that identifies a person, employer, account, or system may enter
it — not in skills, assets, hooks, examples, commit messages, or issue text.

Never commit:

- Names, emails, addresses, phone numbers, government IDs (SSN/TIN), dates of birth
- Account numbers or fragments, routing numbers, card numbers, portfolio balances, salary or
  income figures, ticker symbols tied to a specific person's holdings
- Employer names, internal hostnames, project codenames, customer names
- API keys, tokens, credentials — including expired or revoked ones
- Absolute paths containing a username (`/home/<user>/…`, `/Users/<user>/…`)
- Real file names or URLs from someone's documents, drives, or ticket tracker

(Author attribution in `plugin.json` / `marketplace.json` is deliberate and exempt.)

Write skills so the constraint costs nothing:

- Encode **the rule, not the instance.** "Brokers must exclude compensation income from reported
  basis for covered shares" travels; "the ACME lot of 100 sold 06/03 for $4,469.17" does not, and
  teaches less.
- When a real case motivated the guidance, keep the **shape and the surprise**, drop the
  identifiers: "observed: PDF import produced two records holding two of three subtotals and
  nothing else." That is the reusable part.
- Illustrative numbers should be obviously synthetic and round.
- Date-stamp vendor behaviour (`verified 2026-07`), since that is what actually goes stale.

If a skill genuinely needs a private specific, it belongs in the consuming project's own `.claude/`
or in personal agent memory — never here. The "Project binding" section every skill carries is the
seam that keeps private values outside this repo.

Before committing: reread the diff and ask "would I post this to a public timeline?" If a sentence
only makes sense because you know whose situation it came from, rewrite it.

## Notes

- **Statusline can't be shipped here.** Claude Code only honors `statusLine` from user
  `settings.json`; a plugin's bundled settings support only the `agent` and
  `subagentStatusLine` keys. Keep any custom statusline in your dotfiles.
- **Avoid double-loading when migrating.** If a hook or agent also exists under
  `~/.claude` (e.g. via dotfiles), remove the original after enabling the plugin —
  hooks from multiple sources combine (fire twice) and user-level agents shadow
  plugin agents.
