#!/usr/bin/env bash
set -euo pipefail

: "${TRILIUM_BASE_URL:?Missing TRILIUM_BASE_URL}"
: "${TRILIUM_API_TOKEN:?Missing TRILIUM_API_TOKEN}"

root_json="$(node ./tools/trilium-etapi.mjs ensure-openclaw-root)"
root_id="$(python3 -c '
import json,sys
obj=json.loads(sys.stdin.read())
nid=obj.get("openclawRootNoteId")
if not isinstance(nid,str) or not nid:
    sys.exit(1)
print(nid)
' <<<"$root_json")"

# Create child note
create_json="$(node ./tools/trilium-etapi.mjs create-note --parent "$root_id" --title "B5 Verify $(date -u +%Y%m%dT%H%M%SZ)" --type text)"
note_id="$(python3 -c '
import json,sys
obj=json.loads(sys.stdin.read())
d=obj.get("data",{})
def getid(d):
    if isinstance(d,dict):
        for k in ("noteId","id"):
            if isinstance(d.get(k),str): return d[k]
        n=d.get("note")
        if isinstance(n,dict):
            for k in ("noteId","id"):
                if isinstance(n.get(k),str): return n[k]
    return None
nid=getid(d)
if not nid: sys.exit(1)
print(nid)
' <<<"$create_json")"

# Set content
node ./tools/trilium-etapi.mjs set-content --id "$note_id" --text "first line" >/dev/null

# Append
node ./tools/trilium-etapi.mjs append-note --id "$note_id" --text "second line" >/dev/null

# Get content & verify
content_json="$(node ./tools/trilium-etapi.mjs get-content --id "$note_id")"
python3 -c '
import json,sys
obj=json.load(sys.stdin)
c=obj.get("content","")
assert "first line" in c
assert "second line" in c
' <<<"$content_json" >/dev/null

# Cleanup
node ./tools/trilium-etapi.mjs delete-note --id "$note_id" --force >/dev/null

# Log entry test
log_json="$(node ./tools/trilium-etapi.mjs create-log-entry --title "B5 Log $(date -u +%Y%m%dT%H%M%SZ)" --body "log body")"
log_id="$(python3 -c '
import json,sys
obj=json.loads(sys.stdin.read())
nid=obj.get("noteId")
if not isinstance(nid,str) or not nid:
    sys.exit(1)
print(nid)
' <<<"$log_json")"
node ./tools/trilium-etapi.mjs delete-note --id "$log_id" --force >/dev/null

