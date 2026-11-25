#!/usr/bin/env python3
"""Print the ids of every child of every split in a tab, as a JSON list.

The split tree is only in herdr-core's "herdr-app" document; the app's
panes() does not expose it.
"""
import json
import subprocess
import sys

tab = sys.argv[1]
req = (
    '{"jsonrpc":"2.0","id":1,"method":"hello","params":{}}\n'
    '{"jsonrpc":"2.0","id":2,"method":"doc.get","params":{"name":"herdr-app"}}\n'
)
out = subprocess.run(["hc", "connect"], input=req, capture_output=True, text=True, timeout=10).stdout
doc = next(r for r in map(json.loads, out.splitlines()) if r.get("id") == 2)["result"]["value"]


def children(node):
    for child in node.get("children", []):
        yield child["id"]
        yield from children(child)


for space in doc["spaces"]:
    for t in space["tabs"]:
        if t["id"] == tab:
            print(json.dumps(list(children(t["root"]))))
            sys.exit(0)
print("[]")
