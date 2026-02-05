#!/usr/bin/env bash
set -euo pipefail

: "${TRILIUM_BASE_URL:?Missing TRILIUM_BASE_URL}"
: "${TRILIUM_API_TOKEN:?Missing TRILIUM_API_TOKEN}"

node ./tools/trilium-etapi.mjs app-info >/dev/null

# create
create_json="$(node ./tools/trilium-etapi.mjs create-note --parent root --title "B3 Smoke $(date -u +%Y%m%dT%H%M%SZ)" --type text --content "b3 smoketest")"
note_id="$(python3 -c '
import json,sys
obj=json.loads(sys.stdin.read())
data=obj.get("data",{})
for k in ("noteId","id"):
    if isinstance(data, dict) and isinstance(data.get(k), str):
        print(data[k]); sys.exit(0)
note = data.get("note") if isinstance(data, dict) else None
if isinstance(note, dict):
    for k in ("noteId","id"):
        if isinstance(note.get(k), str):
            print(note[k]); sys.exit(0)
sys.exit(1)
' <<<"$create_json")"

# read
node ./tools/trilium-etapi.mjs get-note --id "${note_id}" >/dev/null

# delete (force)
node ./tools/trilium-etapi.mjs delete-note --id "${note_id}" --force >/dev/null

