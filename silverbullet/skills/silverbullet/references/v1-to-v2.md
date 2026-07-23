# v1 -> v2: what changed

SilverBullet 2.x rewrote the server (Deno/TypeScript -> Rust) and replaced nearly every v1
extension mechanism with Space Lua. Most web content, cached documentation, and
`get.silverbullet.md` itself describe v1 and are wrong for a v2 server. Check every item below
before trusting an older source.

## Configuration

| v1 | v2 |
|---|---|
| `SETTINGS.md` page, YAML body | Space Lua `config.set{...}` / `config.set(k, v)`, conventionally on a page named `CONFIG` |
| `SECRETS` page | Gone. No replacement page - secrets are environment/deployment concerns, not space content |
| `space-config` fenced block (YAML) | Gone. Use `config.*` Lua APIs |
| `space-script` fenced block (JavaScript) | Gone. Use Space Lua |

## Queries and live content

| v1 | v2 |
|---|---|
| `#query` Markdown query blocks | Space Lua Integrated Query (SLIQ): `query[[ from ... where ... order by ... limit ... select ... ]]` |
| Live templates `{{expression}}` | `${luaExpression}` - source stays `${...}` on disk, editor live-previews the evaluated value |
| Command links `{[Command Name]}` | `${widgets.commandButton("Command Name")}` |
| Template widgets | `event.listen` render hooks (e.g. `hooks:renderTopWidgets`) returning `widget.new{...}` |

## Federation

**Removed with no replacement.** v1's `!`-prefixed cross-space federated page links do not exist
in v2. Do not propose a workaround that re-implements federation semantics (e.g. faking it with
plugs) unless the user has explicitly accepted that it is unofficial and unsupported - default to
telling the user it's gone.

## Plugs

| v1 | v2 |
|---|---|
| `_plug/` folder in the space holding compiled plugs | Plug files can live **anywhere** in the space; there's no dedicated folder |
| `PLUGS` page listing installed plugs | Gone - no central plug-listing page |
| `libraries:` key in `SETTINGS.md` | Libraries are meta pages tagged `library` with a `files:` frontmatter list |
| `silverbullet plug:compile` / Deno-based build | `silverbulletmd/silverbullet-plug-template` scaffold + `npm install && npm run build` |

## Server and storage

- Server: Deno/TypeScript -> Rust. Ships as a single self-contained binary, or the official Alpine
  Docker image `zefhemel/silverbullet`.
- Client works the same way conceptually (CodeMirror 6 + Preact) but v2 is **sync-mode only** -
  v1's "online mode" (talking directly to the server with no local IndexedDB mirror) was removed.
  Every v2 client is a local-first PWA with an offline cache that syncs back.
- `.silverbullet.db` (the index) is derived from the Markdown, not authoritative, in both
  versions - but in v2 it's explicitly documented as safe to delete and let the client rebuild.

## Sources you can and can't trust

- `get.silverbullet.md` serves **stale v1 content** as of this writing - do not treat it as
  current documentation for a v2 deployment.
- The `silverbulletmd/silverbullet` repo and `zefhemel`'s own libraries are the authoritative v2
  sources.
- Any tutorial, blog post, or Stack Overflow answer that mentions `SETTINGS.md`, `#query`,
  `space-script`, `space-config`, a `PLUGS` page, or federation is describing v1. Treat its
  *concepts* as a rough map, never its exact syntax.
