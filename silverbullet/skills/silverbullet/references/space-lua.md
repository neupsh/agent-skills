# Space Lua

Space Lua is a custom dialect that is roughly 95% standard Lua, with SilverBullet-specific globals
layered on top (`config`, `command`, `actionButton`, `event`, `widget`, `index`, `space`, `tag`).
Don't assume the full standard Lua stdlib is present just because the syntax looks like Lua.

## Fence types

| Fence | Behavior |
|---|---|
| ```` ```space-lua ```` | **Executed.** Runs on space load/reload. Any non-local variable it sets becomes global across the whole space. |
| ```` ```lua ```` | **Inert.** Displayed as a code sample only, never run. Swap to `space-lua` to activate. |
| ```` ```space-style ```` | Space-wide CSS. Order with a `/* priority: n */` comment. |
| `space-config` | **Removed in v2.** Was a YAML block; use `config.*` APIs instead. |
| `space-script` | **Removed in v2.** Was JavaScript; use Space Lua instead. |

## Load order

Multiple `space-lua` blocks across the space all execute at load time. Order is controlled by a
`-- priority: N` comment at the top of the block:

- Higher priority number runs **earlier**.
- No priority comment means the block runs **last**.
- The stdlib itself uses priority 100 for config-layer code, 50 for core behavior, and 10 for
  anything meant to be easy to override from a lower-priority (later-running) space block.

After editing any space-lua block, run the **System: Reload** command (`Ctrl-Alt-r`) - the space
does not automatically re-evaluate Lua on save.

## Live expressions

`${expression}` in page Markdown live-previews the evaluated Lua expression. The source text on
disk stays `${expression}` - only the rendered view shows the evaluated result. This replaces v1's
`{{...}}` live templates.

## Config API

```space-lua
config.define("some.setting", {
  type = "boolean",              -- or "string", "number", etc.
  default = false,
  description = "What this controls.",
  ui = {
    category = "Example",        -- groups related settings in the Configuration Manager UI
    label = "Some setting",
    priority = 10,
  },
})

config.set("some.setting", true)
-- bulk form:
config.set{ ["some.setting"] = true }

local v = config.get("some.setting", false)  -- second arg is the default if unset
```

`config.define` registers a setting's shape (and lets it show up in the Configuration Manager);
`config.set`/`config.get` read and write the value directly. A space doesn't have to call
`config.define` before `config.set` - `define` is for discoverability and UI, not a precondition.

There is no built-in "list of every real config key" in these notes - treat any config key not
explicitly given to you (by the user, the project's own CONFIG page, or official docs) as unknown,
and write examples with an obviously placeholder key (like `some.setting` above) rather than
guessing a plausible-looking one.

## Commands

```space-lua
command.define {
  name = "Hello: World",
  run = function()
    editor.flashNotification("Hello!")
  end,
  key = "Ctrl-Shift-h",    -- optional keybinding
  mac = "Cmd-Shift-h",     -- optional Mac-specific override
  requireMode = "rw",      -- optional: restrict to a page mode
}
```

Action buttons (the small icon buttons in SilverBullet's UI):

```space-lua
actionButton.define {
  icon = "star",
  run = function()
    editor.flashNotification("Starred!")
  end,
}
```

## Events and widgets

```space-lua
event.listen {
  name = "hooks:renderTopWidgets",
  run = function(e)
    return widget.new{ markdown = "Hi from Space Lua", display = "inline" }
  end,
}
```

`widget.new{ markdown = "...", display = "inline" | "block" }` (or `html = "..."` instead of
`markdown`) is the general form. Shortcuts: `widget.markdown(...)`, `widget.html(...)`, and a
sandboxed variant `widget.sandbox{...}` for untrusted/complex content. A command-link widget in
page text is `${widgets.commandButton("Command Name")}` - this replaces v1's `{[Command Name]}`
syntax.

## SLIQ - Space Lua Integrated Query

Query the derived index directly from Lua, or embed a live query in a page:

```space-lua
query[[ from p = index.tag "page" order by p.lastModified desc limit 5 select p.name ]]
```

Embedded live in a page:

```
${query[[ from p = index.tag "page" order by p.lastModified desc limit 5 select p.name ]]}
```

Reproduce this syntax exactly - it is not SQL and not a function call with parentheses; `from`,
`where`, `order by`, `limit`, and `select` are SLIQ keywords inside the `[[ ]]` block. **Lua
equality in a `where` clause is `==`**, not `=`.

Data sources for `from`:

- `index.tag("task")` - objects with a given tag
- `index.objects("space-lua")` - all objects of a given object type
- `index.pages()` - all pages
- `index.tasks()` - all tasks
- `index.tags()` - all known tags
- `index.links()` - all links between pages

## Reading and writing pages from Lua

```space-lua
local text = space.readPage("Some Page")
space.writePage("Some Page", text .. "\nAppended line.\n")

if space.pageExists("Some Page") then
  -- ...
end

space.deletePage("Some Page")
local names = space.listPages()
```

Useful for space-side automation (e.g. a command that appends to today's journal page) as an
alternative to driving the HTTP API from outside the space - see `http-api.md` for the external
equivalent.

## Custom object types

```space-lua
tag.define {
  name = "book",
  schema = {
    title = "string",
    author = "string",
    rating = "number",
  },
  tagPage = "Books",   -- optional: a page that lists/aggregates objects of this tag
}
```

Defining a tag's schema makes objects carrying that tag queryable and validate-able through the
same `index.tag("book")` / SLIQ machinery as built-in object types like `page` and `task`.
