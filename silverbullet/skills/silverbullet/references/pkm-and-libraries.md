# PKM patterns and libraries

## Common patterns

- **Daily notes / journal.** A command or template that creates (or jumps to) today's page under
  a consistent naming scheme (e.g. `Journal/2026-07-23`), so queries can reliably find "recent
  entries" via `index.tag("page")` filtered by name prefix or by `lastModified`.
- **Tasks.** Plain Markdown checkboxes (`[ ]` open, `[x]` done) are first-class indexed objects -
  query them with `index.tasks()` or SLIQ (`from t = index.tag "task" where ...`). No separate
  task-plugin data model is needed for basic tracking.
- **Tags + tag queries.** Any `#tag` in a page becomes queryable via `index.tags()` /
  `index.tag("thattag")`. Use this for lightweight categorization (`#book`, `#project/x`) without
  a schema, or pair it with `tag.define{...}` (see `space-lua.md`) when you want typed fields.
- **New-page templates.** A command (`command.define`) that calls `space.writePage(name, body)`
  with a pre-filled template body is the v2 way to do what a "page template" plugin did in other
  tools - it's just a small Space Lua command, not a separate subsystem.
- **Backlinks.** `index.links()` gives the space's link graph; a widget (`hooks:renderTopWidgets`
  or similar) can render "pages linking here" for the current page from that data.
- **Widgets/banners.** `widget.new{markdown=...}` (or `html=`) via an `event.listen` hook is the
  general mechanism behind anything that looks like a banner, callout, or injected UI block on a
  page - see `space-lua.md` for the full widget API.

## Official libraries

`silverbulletmd/silverbullet-libraries` ships the official set, including at least:

- **Core** - baseline utilities most spaces want.
- **Git** - the git-sync pattern described in `references/git-sync.md`.
- **Tasks** - task-related helpers beyond the raw `index.tasks()` primitive.

## Community

- **Awesome list**: `github.com/gorootde/silverbullet-collection` - curated community plugs and
  libraries; check here before writing a plug from scratch.
- Notable community plugs (verify current status/compatibility before relying on one - community
  plugs move independently of core SilverBullet releases):
  - **treeview** - a navigable page tree sidebar.
  - **silverbullet-ai** - LLM integration (summarization, generation, chat-in-notes).
  - **mindmap** / **markmap** - render Markdown outlines as mind maps.
  - **plantuml** - render PlantUML diagram blocks.
  - **pomodoro** - a Pomodoro timer widget/command.

## Installing a library

Two equivalent paths:

1. **Configuration Manager UI**: open it with the **Configuration: Open** command (`Ctrl-,`), go
   to the **Libraries** tab, and install from there.
2. **Paste Space Lua directly**: add the library's `files:`-tagged meta page (or its Space Lua
   snippet, if distributed as raw code) into your own space and reload.

Prefer the Configuration Manager for anything from the official or awesome-list sources - it's the
supported install path and keeps library provenance visible in the UI, rather than raw pasted code
with no record of where it came from.
