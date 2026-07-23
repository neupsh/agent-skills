# Plugs - building, installing, distributing

A plug is a `*.plug.js` bundle that runs in a sandboxed Web Worker. It never touches the space or
the host directly - it talks only through **syscalls** the runtime provides. v2 has no `_plug/`
folder, no `PLUGS` page, and no `libraries:` key in a settings file - none of v1's plug-loading
plumbing exists.

## Manifest

Each plug ships a single `{name}.plug.yaml` manifest:

```yaml
name: my-plug
requiredPermissions:
  - fetch     # allow outbound network calls
  - shell     # allow shell.run
functions:
  myCommand:
    path: "myfile.ts:myExportedFunction"
    command:
      name: "My Plug: Do The Thing"
    # events: ["some:event"]        # instead of/in addition to command
    # syscall: "myplug.doTheThing"  # expose as a callable syscall for other plugs
    # redirect: "some/route"        # HTTP route redirect, if applicable
assets:
  - "static/*"
build:
  esbuild: {}   # or whatever the template's build config specifies
```

Manifest keys:

- `name` - plug identifier.
- `requiredPermissions` - declare `fetch` and/or `shell` if the plug's code needs them; omitted
  permissions are simply unavailable to the plug's syscalls at runtime.
- `functions` - a map of function name to `{ path, command, events, syscall, redirect }`. `path`
  is `file.ts:exportedFunctionName`. A function can be a `command` (shows up in the command
  palette), an `events` handler (fires on named events), a `syscall` (callable by other plugs), or
  a route `redirect` - use whichever hooks the plug needs.
- `assets` - static files bundled alongside the compiled JS.
- `build` - build tool configuration, following the plug template's defaults unless you have a
  reason to change them.

## Minimal example

`myplug.plug.yaml`:

```yaml
name: myplug
requiredPermissions: []
functions:
  sayHello:
    path: "myplug.ts:sayHello"
    command:
      name: "My Plug: Say Hello"
```

`myplug.ts`:

```typescript
import { editor } from "@silverbulletmd/silverbullet/syscalls";

export async function sayHello() {
  await editor.flashNotification("Hello from myplug!");
}
```

## Build (v2)

1. Scaffold a new plug from `silverbulletmd/silverbullet-plug-template` (clone/degit it, don't
   start from a blank repo - the template carries the correct build tooling).
2. `npm install`
3. `npm run build` -> produces `{name}.plug.js`.

v1's `silverbullet plug:compile` command and Deno-based build path are legacy - don't reach for
them on a v2 project; use the npm-based template build instead.

## Install

Copy the built `.plug.js` file **anywhere** inside the space (no dedicated folder is required),
then run the **Plugs: Reload** command. The plug hot-reloads within seconds - no server restart.

## Distribute via a library

A library is a **meta page** tagged `library`, with a `files:` frontmatter key listing one or more
`.plug.js` URLs (and/or other library resources):

```
---
tags: library
files:
  - "https://example.invalid/myplug/myplug.plug.js"
---
```

Users install it with the **Library: Install** command (or **Library: Add Repository** for a
whole collection of libraries). This is the v2 equivalent of the manual "download and drop a
`.plug.js` into `_plug/`" flow from v1.

## Syscalls and shell access

Syscalls are the only way a plug (or Space Lua) touches the outside world. The one most relevant
to automation:

```typescript
const result = await shell.run(cmd, argsTable);
// result: { code, stdout, stderr }
```

- Runs with **cwd = the space folder** and **inherits the server's environment**.
- A plug must declare `requiredPermissions: [shell]` to call it; Space Lua can call `shell.run`
  directly without a manifest permission (the risk is at the server-config level - see below).

### The `SB_SHELL_BACKEND` gotcha

Shell execution is enabled **only when `SB_SHELL_BACKEND` is unset**. Setting it to *any* value -
including something that sounds like "yes, use the local shell" such as `"local"` - **disables**
shell instead. This is the opposite of what the variable name suggests; verify by checking whether
it's set at all, not what it's set to.

Shell is also disabled under `SB_READ_ONLY`, and only works when the space uses local-folder
storage (not every storage backend supports it).

Restrict which commands can run with `SB_SHELL_WHITELIST="git pandoc"` - it matches on the
**first word only** of the command line, so whitelisting `git` allows any `git` subcommand.

### Security

Any Space Lua block or any installed plug/library can execute shell commands as the server's OS
user, in the space directory, if shell is enabled. This is a real remote-code-execution surface
once combined with an unauthenticated or under-authenticated `/.fs` write path (see
`http-api.md`'s Safety section) - keep auth on, keep the shell whitelist minimal, and only install
plugs and libraries from sources you trust.
