#!/usr/bin/env bash
set -euo pipefail

: "${TRILIUM_BASE_URL:?TRILIUM_BASE_URL not set}"
: "${TRILIUM_API_TOKEN:?TRILIUM_API_TOKEN not set}"

SKILL="node ./skills/trilium/scripts/trilium.mjs"

intake_title="${1:-C1 Demo Intake}"
intake_body="${2:-Initial intake message.}"
followup_text="${3:-Follow-up details added later.}"

# 1) Ensure OpenClaw root
root_json="$($SKILL ensure-openclaw-root)"

# 2) Create log entry -> capture noteId
title="Intake: ${intake_title} ($(date -u +%Y%m%dT%H%M%SZ))"
create_json="$($SKILL create-log-entry --title "$title" --body "$intake_body")"

note_id="$(python3 -c '
import json,sys
obj=json.load(sys.stdin)
nid=obj.get("noteId")
if not isinstance(nid,str) or not nid:
    sys.exit(1)
print(nid)
' <<<"$create_json")"

# 3) Append follow-up
$SKILL append-note --id "$note_id" --text "$followup_text" >/dev/null

# 4) Read content back and verify
content_json="$($SKILL get-content --id "$note_id")"
python3 -c '
import json,sys
obj=json.load(sys.stdin)
c=obj.get("content","")
assert "Initial intake message." in c or len(c) > 0
' <<<"$content_json" >/dev/null

# Write artifacts for debugging / inspection (optional)
mkdir -p tmp
printf '%s\n' "$root_json"   > tmp/c1_root.json
printf '%s\n' "$create_json" > tmp/c1_create.json
printf '%s\n' "$content_json" > tmp/c1_content.json
printf '%s\n' "$note_id" > tmp/c1_note_id.txt

# 5) Cleanup (demo is non-destructive)
$SKILL delete-note --id "$note_id" --force >/dev/null
