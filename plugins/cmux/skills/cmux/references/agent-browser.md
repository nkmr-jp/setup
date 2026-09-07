# cmux agent-browser reference

A cmux surface can host a **browser** as well as a terminal. The `cmux browser` subcommands provide a Playwright-like CLI optimized for AI agents controlling web interfaces.

## Syntax

```bash
# Full form
cmux browser --surface <surface-id> <subcommand> [args...]

# Short form
cmux browser <surface-id> <subcommand> [args...]
```

Omitting `--surface` selects the short form.

## Startup and connectivity

### Create a browser surface

```bash
cmux --json browser open https://example.com
# => {"surface":"surface:7"}
```

Use the returned `surface:7` in subsequent operations.

### Inspect the context

```bash
cmux identify --json
cmux capabilities
cmux browser identify --surface surface:7
```

---

## Navigation and waiting

| Subcommand | Purpose |
|----|----|
| `get url` | Get the current URL |
| `wait --load-state complete --timeout-ms <ms>` | Wait for loading to complete |
| `wait --selector <css> --timeout-ms <ms>` | Wait for an element to appear |
| `goto <url>` | Navigate to a URL |
| `back` / `forward` / `reload` | Navigate history or reload |

```bash
cmux browser surface:7 get url
cmux browser surface:7 wait --load-state complete --timeout-ms 15000
```

---

## Snapshots and references (`e1`, `e2`, ...)

`snapshot --interactive` assigns short references (`e1`, `e2`, ...) to interactive elements. Subsequent operations can target these references or CSS selectors.

```bash
cmux browser surface:7 snapshot --interactive
# Example output:
# @e1: link "More information..."
# @e2: input "email"
# @e3: button "Submit"
```

### Snapshot options

```bash
cmux browser <surface> snapshot [--interactive] [--compact] [--max-depth N]
```

- `--interactive` — Include only interactive elements and assign references
- `--compact` — Produce compact output
- `--max-depth N` — Limit DOM traversal depth

---

## Element interaction

| Subcommand | Purpose |
|----|----|
| `click <ref-or-selector>` | Click |
| `dblclick <ref-or-selector>` | Double-click |
| `hover <ref-or-selector>` | Hover |
| `focus <ref-or-selector>` | Focus |
| `fill <ref-or-selector> <text>` | Clear an input and set its value |
| `type <ref-or-selector> <text>` | Type text character by character |
| `press <key>` | Press a key, such as `Enter` or `Tab` |
| `keydown <key>` / `keyup <key>` | Send individual key events |
| `select <ref-or-selector> <value>` | Choose a `<select>` value |
| `check <ref-or-selector>` / `uncheck <ref-or-selector>` | Toggle a checkbox |
| `scroll [--selector <css>] [--dx N] [--dy N]` | Scroll |

```bash
cmux browser surface:7 fill e1 "hello"
cmux --json browser surface:7 click e2 --snapshot-after
cmux browser surface:7 press Enter
```

`--snapshot-after` returns a fresh snapshot immediately after the action so subsequent operations can use updated references.

---

## Getters

| Subcommand | Purpose |
|----|----|
| `get text body` / `get text <selector-or-ref>` | Get text |
| `get html body` | Get HTML |
| `get value <selector-or-ref>` | Get a form value |
| `get attr <selector-or-ref> --attr <name>` | Get an attribute value |
| `get count <selector-or-ref>` | Count matching elements |
| `get box <selector-or-ref>` | bounding box |
| `get styles <selector-or-ref> --property <css-prop>` | Get a computed style |

```bash
cmux browser surface:1 get text "#email"
cmux browser surface:1 get attr "#email" --attr placeholder
cmux browser surface:1 get count "li.todo"
```

---

## JavaScript evaluation

```bash
cmux browser surface:7 eval 'document.title'
cmux browser surface:7 eval 'Array.from(document.querySelectorAll("a")).map(a => a.href)'
```

---

## Recommended workflow for a stable agent loop

Use three stages for reliable interaction: snapshot, action, then another snapshot.

```bash
# 1. Check the URL (use goto if needed)
cmux browser surface:7 get url

# 2. Wait for loading to complete
cmux browser surface:7 wait --load-state complete --timeout-ms 15000

# 3. Obtain references from a snapshot
cmux browser surface:7 snapshot --interactive

# 4. Perform the action and take an immediate snapshot
cmux --json browser surface:7 click e5 --snapshot-after

# 5. Take another snapshot if needed
cmux browser surface:7 snapshot --interactive
```

### Why this order?

- Old references can become invalid after a DOM update.
- `--snapshot-after` captures the DOM immediately after an action for the next operation.
- Adding `wait --load-state complete` reduces races during dynamic loading.

---

## End-to-end example: submit a form

```bash
# 1. Open a browser surface
cmux --json browser open https://example.com/login
# {"surface":"surface:7"}

# 2. Wait for loading and take a snapshot
cmux browser surface:7 wait --load-state complete --timeout-ms 15000
cmux browser surface:7 snapshot --interactive
# @e1: input "email"
# @e2: input "password"
# @e3: button "Sign in"

# 3. Fill the form and submit it
cmux browser surface:7 fill e1 "user@example.com"
cmux browser surface:7 fill e2 "secret"
cmux --json browser surface:7 click e3 --snapshot-after

# 4. Check the result
cmux browser surface:7 get url
cmux browser surface:7 get text body
```

---

## Troubleshooting

| Symptom | Resolution |
|----|----|
| A reference is invalid | The DOM has changed. Run `snapshot --interactive` again. |
| Loading never completes | Increase `--timeout-ms`. For a dynamic SPA, wait for a specific selector. |
| Clicking has no effect | An overlay may cover the element. Check its position with `get box`. |
| `fill` does not enter a value | The target may be contenteditable rather than an input. Try `type`. |

---

## Related resources

- Full CLI reference: `cli-commands.md`
- Socket API (`browser.*` methods): `socket-api.md`
- Official specification: https://github.com/manaflow-ai/cmux/blob/main/docs/agent-browser-port-spec.md
