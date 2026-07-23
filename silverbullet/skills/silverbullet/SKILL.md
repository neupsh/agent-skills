---
name: silverbullet
description: SilverBullet 2.x - a self-hosted, local-first Markdown notes (PKM/PKIM) system configured and extended entirely through Space Lua. Use when the task mentions SilverBullet, Space Lua, SLIQ queries, meta pages, building or installing a SilverBullet plug/plugin, self-hosting a notes/PKM/PKIM system, or reading/writing notes through SilverBullet's HTTP API. Most existing tutorials and get.silverbullet.md describe SilverBullet 1.x, which this skill corrects.
metadata: {version: 1.0}
---

# silverbullet - SilverBullet 2.x

Framing fact: **v2 replaced nearly every v1 extension mechanism with one embedded language, Space
Lua.** YAML `SETTINGS.md`, `#query` blocks, `space-script`, `space-config`, and federation
(`!`-prefixed pages) are all gone with no drop-in replacement for federation. If a source - a blog
post, a cached doc, `get.silverbullet.md` itself - shows any of those, it is describing v1 and
will not work. See `references/v1-to-v2.md` for the full mapping before trusting any tutorial.

## Mental model

- **Server**: a single self-contained Rust binary, or the official Alpine Docker image
  `zefhemel/silverbullet`.
- **Client**: TypeScript (CodeMirror 6 + Preact), shipped as a local-first PWA. A service worker
  and sync engine mirror the server's files into browser IndexedDB, so the client works offline
  and syncs back. **v2 is sync-mode only** - v1's "online mode" was removed.
- **Space** = a directory of Markdown files (env `SB_FOLDER`, `/space` in the official Docker
  image).
- **Page** `Foo/Bar` = the file `Foo/Bar.md`. The index page is `index.md`.
- **Meta pages** (tagged `#meta*`) hold config and tooling. A `^` caret prefix opts a page into
  autocomplete.
- Storage is plain Markdown. The index/objects layer is *derived* from the Markdown, not the
  source of truth - the `.silverbullet.db` index file is rebuildable and safe to delete.

## When to use / when NOT to use

Use when:
- Configuring a space, writing commands/queries/widgets, or debugging Space Lua.
- Reading or writing notes programmatically (an agent maintaining a journal, syncing external
  data into pages, bulk edits).
- Building, packaging, or installing a SilverBullet plug.
- Setting up git-based backup/sync for a space.
- Any "self-host a PKM/PKIM/notes system" task where SilverBullet is the target.
- Migrating a v1 space or config to v2.

Do NOT use when:
- The target is Obsidian, Logseq, Notion, or another PKM tool - don't cross-apply SilverBullet
  specifics to a different product.
- The task wants federation (`!`-prefixed cross-space page links). It was removed in v2 with no
  replacement - don't invent one, and say so if asked.
- The task is generic Lua unrelated to SilverBullet. Space Lua is a ~95%-Lua dialect with
  SilverBullet-specific globals (`config`, `space`, `index`, `widget`, ...) layered on top - don't
  assume the full standard Lua stdlib is present.

## Core workflow 1: configure via Space Lua

There is no settings file. Configuration is Lua code that runs when the space loads, conventionally
placed on a page named `CONFIG` (tag it `#meta` if you don't want it cluttering search).

A ```` ```space-lua ```` fenced block is **executed**, and any non-local variable it sets becomes
**global across the whole space**. A plain ```` ```lua ```` block is inert - display-only, never
run. Swap the fence language to activate it. Load order across multiple space-lua blocks is
controlled with a `-- priority: N` comment (higher runs earlier; no comment means it runs last;
the stdlib itself uses priority 100 for config, 50 for core, 10 for anything meant to be overridden).

```space-lua
-- priority: 100
config.define("some.setting", {
  type = "boolean",
  default = false,
  description = "Placeholder - replace with a real config key for your space.",
  ui = { category = "Example", label = "Some setting", priority = 10 },
})

config.set("some.setting", true)
-- or bulk form: config.set{ ["some.setting"] = true }
```

Read a value back with `config.get("some.setting", defaultValue)`. After editing a space-lua
block, run the **System: Reload** command (`Ctrl-Alt-r`) - edits don't take effect until reload.

Live values in page text use `${...}` expressions (the v1 `{{...}}` template syntax is gone):
the source stays `${...}` on disk and the editor live-previews the evaluated result inline.

Custom commands and action buttons:

```space-lua
command.define {
  name = "Hello: World",
  run = function()
    editor.flashNotification("Hello!")
  end,
  -- optional: key = "Ctrl-Shift-h", mac = "Cmd-Shift-h", requireMode = "rw"
}
```

Widgets and render hooks (the v1 replacement for template widgets and command links):

```space-lua
event.listen {
  name = "hooks:renderTopWidgets",
  run = function(e)
    return widget.new{ markdown = "Hi from Space Lua", display = "inline" }
  end,
}
```

`widget.new{markdown=|html=, display="inline"|"block"}` has shortcuts `widget.markdown(...)`,
`widget.html(...)`, and a sandboxed form `widget.sandbox{...}`. A command link in a page becomes
`${widgets.commandButton("Hello: World")}`.

Space-wide CSS lives in a ```` ```space-style ```` fence (`/* priority: n */` for ordering).

Full API surface (config, commands, events, widgets, custom tag types, SLIQ query API):
`references/space-lua.md`.

## Core workflow 2: SLIQ queries

v1's `#query` blocks are gone. Space Lua Integrated Query (SLIQ) reads the derived index:

```space-lua
query[[ from p = index.tag "page" order by p.lastModified desc limit 5 select p.name ]]
```

Embed a query live in a page as `${query[[ ... ]]}`. Data sources: `index.tag("task")`,
`index.objects("space-lua")`, `index.pages()`, `index.tasks()`, `index.tags()`, `index.links()`.
Lua equality in a `where` clause is `==`, not `=`. Details and more examples:
`references/space-lua.md`.

## Core workflow 3: read/write notes via the HTTP API

An external agent (this one, or another process) can read and edit pages over HTTP without going
through the editor. Files live under `/.fs`; `Foo/Bar` maps to `/.fs/Foo/Bar.md` (URL-encode
spaces). Always send `X-Sync-Mode: true` - without it the server treats a `.md` GET as browser
navigation and redirects to the UI instead of returning content.

```bash
# TOKEN and BASE come from the project binding below - never hardcode them here.
H=(-H "Authorization: Bearer $TOKEN" -H "X-Sync-Mode: true")

curl -s "${H[@]}" "$BASE/.fs"                          # list all files + metadata
curl -s "${H[@]}" "$BASE/.fs/index.md"                 # read a page
curl -s "${H[@]}" --data-binary @new.md -X PUT "$BASE/.fs/Some%20Page.md"   # write (whole file)
curl -s "${H[@]}" -X DELETE "$BASE/.fs/Some%20Page.md" # delete
```

There is no patch endpoint - every write is whole-file: GET, modify the text, PUT the whole thing
back. Writing a `.md` file does not instantly re-index it; the client re-indexes on load or via
**Space: Reindex**. Full header reference, auth model (bearer token, not HTTP Basic), and safety
notes for agent clients: `references/http-api.md`.

## Core workflow 4: build and install a plug

A plug is a sandboxed `*.plug.js` bundle (Web Worker, talks only via syscalls) plus a
`{name}.plug.yaml` manifest declaring commands/events/functions and `requiredPermissions`
(`fetch`, `shell`). Scaffold from `silverbulletmd/silverbullet-plug-template`, then
`npm install && npm run build` to produce the `.plug.js`. Install by copying that file **anywhere**
in the space and running **Plugs: Reload** - there is no `_plug/` folder or `PLUGS` page in v2.
Distribute via a **library**: a meta page tagged `library` with a `files:` frontmatter list of
`.plug.js` URLs; users run **Library: Install**. Manifest shape, syscalls (including
`shell.run` and the `SB_SHELL_BACKEND` gotcha), and a minimal example: `references/plugs.md`.

## Core workflow 5: git sync

Not built in. The community pattern is a Space Lua library that shells out to `git` on a
`cron:secondPassed` event, gated by `config.get("git.autoSync")` minutes:
`config.set("git.autoSync", 5)` turns it on. Requires shell enabled (`SB_SHELL_BACKEND` unset), a
git repo with a remote in the space folder, and `git config user.email` set. Full setup, auth
options (HTTPS token vs. SSH deploy key), and gotchas (`git diff --exit-code` misses untracked
new pages, the library swallows commit errors silently): `references/git-sync.md`.

## Core workflow 6: PKM patterns

Daily notes/journals, task tracking (`[ ]`/`[x]` + `index.tasks()`), tag queries, new-page
templates, backlinks, banner widgets - and the official/community libraries and plugs that
implement them. `references/pkm-and-libraries.md`.

## Safety

- **Unauthenticated by default.** A bare SilverBullet server has no auth - anyone reaching the
  port can read and write every page. Set `SB_AUTH_TOKEN` (bearer token, for API clients) and/or
  `SB_USER` (form login, for the browser UI), or front it with an auth proxy. `GET /.ping` is an
  intentionally unauthenticated health check - its reachability is not a vulnerability.
- **No HTTP Basic auth in v2.** `curl -u user:pass` will not work against `/.fs`. Use
  `Authorization: Bearer <token>`.
- **Keep the token out of model context and transcripts.** Read it from environment/config at
  call time; never have an agent print it, log it, or echo it back "to confirm."
- **Harden agent-driven paths.** Reject `..` and absolute paths before building a `/.fs/<path>`
  URL; consider scoping an agent's writes to a page-name prefix it owns.
- **Shell is a real code-execution surface.** Any installed library or Space Lua block that calls
  `shell.run` executes as the server's user in the space directory. Keep `SB_SHELL_WHITELIST`
  minimal, keep auth on, and only install plugs/libraries you trust.
- **`SB_SHELL_BACKEND` is a trap.** Shell execution is enabled only when this variable is
  **unset**. Setting it to any value - even `"local"` - disables shell, contrary to what the
  variable name suggests.

## Project binding

Deployment-specific values do not belong in this skill and must not be hardcoded from it - look
them up in the consuming project's own `.claude/` config or a private personal skill:

- Base URL / hostname and port.
- `SB_AUTH_TOKEN` or `SB_USER` credentials, and whether an auth proxy sits in front.
- Container vs. bare-binary deployment details, and the space's on-disk/volume path.
- The notes' git remote and auth method, if git sync is set up.
- Any reverse-proxy or network-boundary specifics.

If none of this is documented yet, that's a gap in the project's own docs to fill - not something
to guess into this skill.

## Reference index

- `references/v1-to-v2.md` - full v1 -> v2 change list; read before trusting any older tutorial.
- `references/space-lua.md` - fence types, full config/command/event/widget/query API, load order.
- `references/http-api.md` - `/.fs` endpoints, headers, auth model, copy-paste curl workflow.
- `references/plugs.md` - manifest schema, syscalls, shell permissions, build and install steps.
- `references/git-sync.md` - the Space Lua git-sync pattern, auth options, gotchas, alternatives.
- `references/pkm-and-libraries.md` - PKM patterns, official libraries, community plugs.
