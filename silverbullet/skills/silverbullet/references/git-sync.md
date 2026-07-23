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

## Running both in-app AND a host cron: the two-writer ownership trap

If you keep the in-app library (for a manual "commit now" button) *and* run a host cron on the same
bind-mounted `.git`, two different users write the repository: the container app (usually a
non-root uid) and the host cron (usually root). This has two failure modes worth designing around:

- **Dubious ownership.** Modern git refuses to operate on a repo whose top-level/`.git` is owned by
  a *different* uid than the process (CVE-2022-24765): `fatal: detected dubious ownership`. If the
  host (root) initialized the repo, the container app (non-root) will hit this. Fix by aligning
  ownership - `chown -R <app-uid>:<app-gid> .git` - or by whitelisting the path in the *global*
  git config of whichever user trips it (`git config --global --add safe.directory <path>`;
  `safe.directory` is ignored from the repo's own config, by design).
- **Diverging object ownership over time.** Once both users commit, each creates new loose objects
  and shard directories (`.git/objects/xx/`) owned by itself. The other user must still be able to
  add files into those shard dirs. The standard fix is `git config core.sharedRepository group`
  plus a common group and setgid dirs - **but setgid directory-GID inheritance is not honored on
  every filesystem** (notably FUSE overlays such as Unraid's `/mnt/user` shfs). Where inheritance
  doesn't work, root-created shard dirs come out with root's gid and the app user can't write them,
  so in-app commits start failing days later once fresh shards appear. The portable fix: have the
  host cron **re-assert ownership at the end of each run**, e.g.
  `find .git \( ! -uid <app-uid> -o ! -gid <app-gid> \) -exec chown <app-uid>:<app-gid> {} +`.
  A one-off `chown` is not enough - it passes an immediate test and silently regresses.

Note also that if the container has **no ssh client**, the in-app side can only ever *commit*
locally; the host cron (or an HTTPS-token remote) is what actually pushes.
