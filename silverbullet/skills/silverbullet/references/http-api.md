# HTTP API - reading and writing notes externally

SilverBullet exposes the space's files directly under `/.fs`. This is how an external agent (or
any script) reads and edits pages without going through the editor UI.

## Endpoints

| Method | Path | Effect |
|---|---|---|
| `GET` | `/.fs` | JSON list of **all** files in the space plus metadata. Filter to `*.md` for pages. |
| `GET` | `/.fs/<path>` | Read the raw file content. |
| `PUT` | `/.fs/<path>` | Write the file - **whole-file replace**, no patch/partial-update endpoint. |
| `DELETE` | `/.fs/<path>` | Delete the file. |
| `GET` | `/.ping` | Unauthenticated health check. |

## Page-to-path mapping

- Page `Foo/Bar` -> `/.fs/Foo/Bar.md`.
- The index page -> `/.fs/index.md`.
- URL-encode spaces and other special characters: page `Space Lua` -> `/.fs/Space%20Lua.md`.

## Required header

**Always send `X-Sync-Mode: true` on every `/.fs` request.** Without it, the server treats a
`GET` for a `.md` path as a browser navigating to that page in the UI and issues a redirect
instead of returning the raw file - a script that omits this header gets HTML back, not content.

## Metadata headers

Responses carry:

- `X-Last-Modified` - unix ms timestamp of last write.
- `X-Created` - unix ms timestamp of creation.
- `X-Permission` - `rw` or `ro`.

Request `X-Get-Meta: true` to get metadata only, without the file body - useful for checking
whether a page changed before deciding to re-fetch and re-write it.

## Auth

v2 has **no HTTP Basic auth**. `curl -u user:pass` will not authenticate against `/.fs`.

- **API/agent clients**: `Authorization: Bearer <token>`, where the token is whatever value the
  server's `SB_AUTH_TOKEN` environment variable was set to.
- **Browser UI login**: `SB_USER=user:pass` configures a **form** login - the browser POSTs
  credentials to `/.auth` and gets a session cookie back. This is not an HTTP Basic credential and
  cannot be used with `curl -u`.
- **Out of the box, the server is unauthenticated** - anyone who can reach the port can read and
  write every page. Set `SB_AUTH_TOKEN` and/or `SB_USER`, or put an authenticating reverse proxy
  in front, before exposing a SilverBullet instance beyond localhost.
- `GET /.ping` is deliberately open (health check) - its being reachable without auth is not a
  misconfiguration.

## Copy-pasteable workflow

```bash
# TOKEN and BASE are deployment-specific - read them from the project's own binding
# (see the skill's Project binding section), never hardcode or print them.
BASE="$BASE_URL"
H=(-H "Authorization: Bearer $TOKEN" -H "X-Sync-Mode: true")

# List everything (pipe through jq to filter to pages):
curl -s "${H[@]}" "$BASE/.fs" | jq '[.[] | select(.name | endswith(".md"))]'

# Read a page:
curl -s "${H[@]}" "$BASE/.fs/index.md"

# Read metadata only (no body):
curl -s "${H[@]}" -H "X-Get-Meta: true" "$BASE/.fs/index.md"

# Write a page - GET, edit the text locally, then PUT the whole thing back:
curl -s "${H[@]}" "$BASE/.fs/Journal/2026-07-23.md" -o /tmp/page.md
# ... edit /tmp/page.md ...
curl -s "${H[@]}" --data-binary @/tmp/page.md -X PUT "$BASE/.fs/Journal/2026-07-23.md"

# Delete:
curl -s "${H[@]}" -X DELETE "$BASE/.fs/Scratch/tmp-note.md"
```

## Indexing is not instant

Writing a `.md` file via `PUT` updates the file but does **not** immediately update the derived
index (tags, links, queries). The client re-indexes when it next loads the affected page, or an
agent can trigger it explicitly with the **Space: Reindex** command. If a script writes a page and
then immediately runs a SLIQ query expecting to see it, that race is the likely cause of a stale
result - not a bug in the query.

## Safety for agent clients

- **Keep the token server-side.** Never place it in a prompt, log it, or have a model echo it
  "to confirm it loaded" - read it from the environment/secret store at call time only.
- **Harden the path.** Before building a `/.fs/<path>` URL from a model-provided page name, reject
  `..` segments and absolute paths - a naive join lets a compromised or confused agent read/write
  outside the intended page tree.
- **Consider prefix-scoping.** If an agent only needs to manage its own notes, restrict its writes
  to a page-name prefix (e.g. only `Agent/*.md`) at the calling layer - the API itself has no
  built-in per-path ACL beyond the single `rw`/`ro` permission bit.
- **Remember every write is whole-file.** Two concurrent writers to the same page will race; use
  `X-Last-Modified` to detect a page changed since your last `GET` before blindly overwriting it.
