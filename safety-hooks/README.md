# safety-hooks

Defensive `PreToolUse` guards for Bash.

## What it does

`scripts/block-proc-search.sh` runs before every Bash tool call and **denies**
`grep`/`ugrep`/`rg`/`ag`/`find`/`fd` commands that target a virtual filesystem
(`/proc`, `/sys`, `/dev`). Searching those can trigger infinite reads and pin CPU
for hours. Everything else is allowed through untouched.

Requires `jq` on `PATH`.

## Install

```
/plugin marketplace add neupsh/agent-skills
/plugin install safety-hooks@neupsh-skills
```

Once enabled, the hook is wired automatically via `hooks/hooks.json` — no
`settings.json` editing needed. If you previously ran this script from a personal
`~/.claude/hooks` + `settings.json` entry, remove that entry so it doesn't fire twice.
