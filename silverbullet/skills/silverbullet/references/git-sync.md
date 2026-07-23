# Git sync

SilverBullet has no built-in git integration. The community pattern is a **Space Lua library**
(zefhemel's `Git` library) that shells out to the `git` binary on a timer, plus manual commands.

## How the library pattern works

On a `cron:secondPassed` event, the library checks whether enough minutes have elapsed since the
last sync (`config.get("git.autoSync")` minutes) and if so runs, in order:

1. `git add ./*`
2. Check for changes with `git diff --exit-code` (see gotcha below) - only commits if something
   changed.
3. `git commit -a -m "Snapshot"`
4. `git pull`
5. `git push`

Plus manual commands: **Git: Sync** and **Git: Commit**, for triggering the same flow on demand
instead of waiting for the timer.

Enable the timer with:

```space-lua
config.set("git.autoSync", 5)   -- minutes between auto-sync attempts
```

## Prerequisites

- `git` present in the runtime the server executes in (the official Docker image ships git, curl,
  and bash already; a bare binary deployment needs `git` on `PATH` separately).
- Shell enabled: `SB_SHELL_BACKEND` must be **unset** (see the gotcha in `plugs.md` - setting it
  to any value, including "local", disables shell).
- A git repository already initialized in the space folder, with a remote configured.
- `git config user.email` (and `user.name`) set for that repo - **commits silently no-op without
  it**. This is not a loud failure; check `git log` in the space folder if auto-sync seems to be
  running but nothing is landing upstream.

## Auth for the remote

Put credentials in `<space>/.git/config`, not anywhere that depends on `$HOME` or a user session -
the server process may not have the same home directory or environment a human's git config
relies on.

- **HTTPS token remote** (simplest): `https://x-access-token:<TOKEN>@host/owner/repo.git` as the
  remote URL. No SSH client needed in the runtime.
- **SSH deploy key** (scoped to one repo): needs an SSH client available in the runtime. If the
  key file lives inside the space folder itself, you must (a) `.gitignore` it so it's never
  committed, and (b) add it to `SB_SPACE_IGNORE` so SilverBullet's own sync engine doesn't mirror
  the key file into every browser client.

Either way, never put the actual token/key value in a Space Lua file, a page, or anywhere the
`/.fs` API can read it back out - git remote credentials belong in `.git/config` on disk, which
sync-mode does not expose through `/.fs`.

## Gotchas

- **`git diff --exit-code` only sees tracked changes.** A brand-new, never-before-committed page
  is untracked, so it alone will not trigger a commit - the sync only fires once some *tracked*
  file also changes, or after an explicit `git add` picks up the new file. Don't assume "I created
  a page and waited 5 minutes" is sufficient to prove auto-sync works; also edit an existing page.
- **The library swallows commit errors.** A failed `git commit` or `git push` (e.g. an expired
  token, a diverged branch) fails silently into the server log rather than surfacing in the UI.
  If sync seems to have stalled, check server logs, not the SilverBullet UI, first.
- `shell.run` executes **inside the server's own runtime/container**, not on the physical host -
  if the server runs in a container, `git` and any deploy key must be present *inside that
  container*, and paths in remote URLs or key files are container-relative.

## Alternative: sync from outside SilverBullet entirely

Instead of the in-app library, run the same add/commit/pull/push sequence as a **cron job on the
host**, operating directly on the space's on-disk folder (bind-mounted out of the container, if
containerized).

Trade-off: more robust (survives a SilverBullet crash or restart, doesn't depend on
`SB_SHELL_BACKEND`, easier to observe with normal host tooling/logging) but loses the in-app
**Git: Sync** button and any Space Lua hooks that react to sync state. Decouples sync reliability
from the SilverBullet process at the cost of a separate thing to maintain.
