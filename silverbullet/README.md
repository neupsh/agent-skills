# silverbullet

A skill for working with **SilverBullet 2.x** - the self-hosted, local-first Markdown notes
(PKM) system. Covers Space Lua (configuration, queries, commands, widgets), the `/.fs` HTTP API
for reading and writing notes, plug development, community git-sync patterns, and common PKM
workflows.

## Why this exists

Most SilverBullet content on the web, and `get.silverbullet.md` itself, describes **v1**. v2
replaced nearly every v1 extension mechanism - YAML `SETTINGS.md`, `#query` blocks,
`space-script`, federation - with a single embedded language, Space Lua, and removed the online
(non-sync) mode entirely. A model answering from pretrained knowledge will confidently produce
v1 answers that do not work against a v2 server. This skill pins down the v2-verified facts so
that doesn't happen.

## The roster

| Skill | What it encodes | Use when |
|-------|-----------------|----------|
| [`silverbullet`](skills/silverbullet/SKILL.md) | Space Lua config/queries/commands/widgets, the HTTP API for agent-driven note read/write, building and installing plugs, git-sync setup, PKM patterns and libraries. | Any task that mentions SilverBullet, Space Lua, or self-hosting a notes/PKM/PKIM system |

## Scope note

Deployment-specific values - base URL, auth token, container details, the notes' git remote,
reverse-proxy setup - are never hardcoded here. See the skill's "Project binding" section: those
values belong in the consuming project's own `.claude/` or a private personal skill.
