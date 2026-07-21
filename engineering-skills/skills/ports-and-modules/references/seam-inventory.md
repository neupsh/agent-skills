# Seam Inventory: Executable Audit Procedure

Run this before proposing any extraction. Output: a ranked, cheapest-first list of seams. Time-box to one working session; you're cataloging, not fixing.

## 0. Map the terrain

```bash
# Largest files = god-component candidates
find . -name '*.go' -not -path '*/vendor/*' | xargs wc -l | sort -rn | head -20
find src -name '*.ts' -o -name '*.tsx' | xargs wc -l | sort -rn | head -20

# Most-imported packages (fan-in) — high fan-in + large file = god component
go list -f '{{range .Imports}}{{.}}{{"\n"}}{{end}}' ./... | sort | uniq -c | sort -rn | head
# Package-level import graph for one suspect package:
go list -f '{{.ImportPath}} -> {{join .Imports "\n  -> "}}' ./internal/engine/...

# JS/TS dependency graph + cycles
npx madge --circular src/
# Python
python -m pip install import-linter && lint-imports  # needs .importlinter config
```

Note the top 3 largest components and any import cycles. Cycles mark places where a seam is impossible until broken.

## 1. Existing interfaces that are bypassed

Find the interfaces the repo already defines:

```bash
# Go: all interface declarations
grep -rn "type .* interface" --include='*.go' . | grep -v _test
# TS
grep -rn "^export interface\|^interface" --include='*.ts' src/
```

For each domain-relevant interface (Provider, Store, Repository, Transport, Client), find call sites using the CONCRETE type instead:

```bash
# Given interface Store implemented by PgStore:
grep -rn '\*PgStore\|&PgStore{' --include='*.go' . | grep -v pgstore  # uses outside its own package
```

Each hit outside the implementing package + its constructor is a bypass. Record: file, line, which interface it should use.

## 2. Concrete-type leaks in signatures

Constructors and functions taking a pointer-to-concrete where an interface exists:

```bash
# Go: params that are pointers to exported structs (heuristic — review hits manually)
grep -rn 'func ' --include='*.go' . | grep -E '\*[A-Z][A-Za-z]+(Store|Client|Provider|Service|Repo)\b'
```

For each: does an interface covering the used methods already exist? If yes → one-line widen (extraction step 1). If no → note which methods the caller actually uses; that method set is the future interface. **Do not widen to a 12-method interface when the caller uses 3 — define the 3-method consumer-side interface.**

## 3. Duplicated switch statements

```bash
# Go: all switches on a type/kind/provider discriminator
grep -rn 'switch .*\(kind\|type\|provider\|channel\|mode\)' --include='*.go' -i .
# Then group by the switched expression; two files switching on the same thing = missing registry.
```

Cheap drift check: for each pair of duplicate switches, diff their case lists. If they already disagree, you've found a live bug — file it separately (behavior fix, own PR), don't fold it into the refactor.

## 4. Hardcoded enum dispatch → registration map

Same grep as #3, but the trigger is different: even a SINGLE switch in shared/core code over an open-ended kind ("adding a new provider means editing this file") is a seam. Closed sets (e.g. switching on 3 fixed states of your own state machine) are fine as switches — don't registry-ify those.

Decision rule: **will a new case be added by someone who shouldn't need to touch this file?** Yes → registry. No → leave the switch.

## 5. Capabilities trapped in one runtime

Hardest to grep, highest value. Procedure:

1. List the domain verbs your product supports (resolve, escalate, transfer, create ticket, summarize, bill...). Pull from the UI, API docs, or tool definitions.
2. For each verb, find its implementation: `grep -rn 'Resolve\|Escalate\|CreateTicket' --include='*.go' .`
3. Flag any verb implemented inside a transport/channel-specific package (e.g. `internal/voice/...`, `internal/telephony/...`) whose semantics don't mention the channel.
4. For each flagged verb, record: current home, what channel-specific state it actually reads (often just a session ID), and the core package it belongs in.

## Ranking the output

Score each seam: **value** (how many future changes it unblocks; does it collapse a test-cost tier?) vs **cost** (lines touched, callers affected, does it need characterization tests first?). Sort cheapest-first within the highest value band. The list becomes your extraction roadmap; each entry should name the PR-sized unit.

## Circular-dependency gates (use in Definition of Done)

```bash
# Go — a cycle fails the build, so compiling is the check; for architecture layering:
go vet ./... && go build ./...
# Optional layering enforcement: github.com/roblaszczak/go-cleanarch or a depguard rule in .golangci.yml
# JS/TS
npx madge --circular src/ && echo OK
# Python
lint-imports
```

Add the relevant command to CI in the same PR series that creates the first core package — layering rules that aren't enforced decay in weeks.
