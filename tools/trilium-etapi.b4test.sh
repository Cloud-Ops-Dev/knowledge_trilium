#!/usr/bin/env bash
set -euo pipefail

: "${TRILIUM_BASE_URL:?Missing TRILIUM_BASE_URL}"
: "${TRILIUM_API_TOKEN:?Missing TRILIUM_API_TOKEN}"

# Ensure root note exists and store id
root_json="$(node ./tools/trilium-etapi.mjs ensure-openclaw-root)"
root_id="$(python3 -c '
import json,sys
obj=json.loads(sys.stdin.read())
nid=obj.get("openclawRootNoteId")
if not isinstance(nid,str) or not nid:
    sys.exit(1)
print(nid)
' <<<"$root_json")"

# Create a child note under OpenClaw root
create_json="$(node ./tools/trilium-etapi.mjs create-note --parent "$root_id" --title "B4 Child $(date -u +%Y%m%dT%H%M%SZ)" --type text --content "initial")"
note_id="$(python3 -c '
import json,sys
obj=json.loads(sys.stdin.read())
data=obj.get("data",{})
def getid(d):
    if isinstance(d,dict):
        for k in ("noteId","id"):
            if isinstance(d.get(k),str): return d[k]
        n=d.get("note")
        if isinstance(n,dict):
            for k in ("noteId","id"):
                if isinstance(n.get(k),str): return n[k]
    return None
nid=getid(data)
if not nid: sys.exit(1)
print(nid)
' <<<"$create_json")"

# Append (may fail if ETAPI does not support update)
node ./tools/trilium-etapi.mjs append-note --id "$note_id" --text "appended line" >/dev/null

# Delete the child note (cleanup)
node ./tools/trilium-etapi.mjs delete-note --id "$note_id" --force >/dev/null
