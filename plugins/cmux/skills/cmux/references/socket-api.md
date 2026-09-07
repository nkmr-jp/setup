# cmux socket API reference

cmux.app accepts JSON-RPC requests on the UNIX domain socket `/tmp/cmux.sock`. CLI commands are thin wrappers around socket calls; scripts can also call the socket directly.

## Transport specification (V2 protocol)

- Path: `/tmp/cmux.sock`
- Format: **newline-delimited JSON (NDJSON)**
- One request per line and one response per line

### Request format

```json
{"id":"<string>","method":"<namespace>.<action>","params":{...}}
```

| Field | Type | Description |
|----|----|----|
| `id` | string | An arbitrary caller-provided ID, echoed in the response |
| `method` | string | `<namespace>.<action>`, such as `workspace.list` |
| `params` | object | Method-specific parameters; pass `{}` even when empty |

### Response format

Success:

```json
{"id":"1","ok":true,"result":{...}}
```

Failure:

```json
{"id":"1","ok":false,"error":{"code":"not_found","message":"workspace not found"}}
```

---

## Invocation examples

### netcat (minimal setup)

```bash
echo '{"id":"1","method":"workspace.list","params":{}}' | nc -U /tmp/cmux.sock
```

### Python

```python
import json, socket

def call(method, params=None, req_id="1"):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect("/tmp/cmux.sock")
    payload = json.dumps({"id": req_id, "method": method, "params": params or {}})
    s.sendall((payload + "\n").encode())
    data = s.recv(65536)
    s.close()
    return json.loads(data.decode().strip())

print(call("workspace.list"))
print(call("notification.create", {"title": "Hi", "body": "Hello"}))
```

### Bash + jq

```bash
nc -U /tmp/cmux.sock <<EOF | jq
{"id":"1","method":"workspace.list","params":{}}
EOF
```

---

## Main methods

### window.*

| Method | params | Description |
|----|----|----|
| `window.list` | `{}` | List windows |
| `window.create` | `{}` | Create a window |

### workspace.*

| Method | params | Description |
|----|----|----|
| `workspace.list` | `{ "window_id"?: string }` | List workspaces |
| `workspace.create` | `{ "cwd"?: string, "window_id"?: string }` | Create a workspace |
| `workspace.select` | `{ "workspace_id": string }` | Switch focus |
| `workspace.current` | `{}` | Return the currently focused workspace |
| `workspace.close` | `{ "workspace_id": string }` | Close a workspace |
| `workspace.move_to_window` | `{ "workspace_id": string, "window_id": string }` | Move to another window |

### pane.* / surface.*

| Method | params | Description |
|----|----|----|
| `pane.list` | `{ "workspace_id"?: string }` | List panes |
| `pane.split` | `{ "pane_id": string, "direction": "right\|down\|left\|up" }` | Split a pane |
| `surface.list` | `{ "pane_id": string }` | List surfaces |
| `surface.move` | `{ "surface_id": string, "pane_id": string, "focus"?: bool }` | Move a surface |
| `surface.reorder` | `{ "surface_id": string, "before"?: string, "after"?: string }` | Reorder surfaces |
| `surface.trigger_flash` | `{ "surface_id"?: string, "workspace_id"?: string }` | Draw visual attention |

### notification.*

| Method | params | Description |
|----|----|----|
| `notification.create` | `{ "title": string, "subtitle"?: string, "body"?: string, "workspace_id"?: string }` | Create a notification |
| `notification.list` | `{}` | List notifications |
| `notification.clear` | `{}` | Clear all notifications |

### status.*

| Method | params | Description |
|----|----|----|
| `status.set` | `{ "key": string, "value": string }` | Set status |
| `status.clear` | `{ "key": string }` | Remove status |

### identify / capabilities

| Method | params | Description |
|----|----|----|
| `identify` | `{}` | Return the caller's location |
| `capabilities` | `{}` | Return supported capabilities |

### browser.*

See `agent-browser.md` for methods such as `browser.open`, `browser.click`, `browser.fill`, and `browser.snapshot`.

---

## Error codes

| code | Meaning |
|----|----|
| `not_found` | No resource exists for the specified ID |
| `invalid_params` | Missing parameters or mismatched types |
| `unsupported` | Not supported in an older version |
| `internal` | Internal error |

---

## Best practices and caveats

- **Send IDs as strings**, including numeric-looking IDs such as `"1"`.
- **Set a caller-side timeout**: the socket can hang when cmux.app exits.
- **Multiple calls** may reuse a connection, but connecting once per command is safer for reliability.
- **The CLI and API are equivalent**. A practical workflow is to verify operations with the CLI, then use the API when scripting them.
