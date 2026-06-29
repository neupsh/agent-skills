# agent-skills

A Claude Code **plugin marketplace** — a home for reusable skills, plugins, hooks,
and agents.

## Use it

Add the marketplace, then install whichever plugins you want:

```
/plugin marketplace add neupsh/agent-skills
/plugin install design-system@agent-skills
```

Or wire it into `settings.json` so it travels with your dotfiles:

```json
{
  "extraKnownMarketplaces": {
    "agent-skills": {
      "source": { "source": "github", "repo": "neupsh/agent-skills" }
    }
  },
  "enabledPlugins": {
    "design-system@agent-skills": true
  }
}
```

## Plugins

| Plugin | What it does |
|---|---|
| [`design-system`](./design-system) | Apply a reusable, token-driven design system to any web UI — OKLCH color ramps, type pairing, layered elevation, density + light/dark theming, and class-and-token component primitives. |

## Layout

```
.claude-plugin/marketplace.json   # marketplace manifest (must be at repo root)
design-system/                    # a plugin
  .claude-plugin/plugin.json
  skills/ assets/ README.md
```

Each plugin is independently installable, so you can enable only what you need.
