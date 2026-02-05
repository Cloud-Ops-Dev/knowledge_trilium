#!/usr/bin/env bash
set -euo pipefail

: "${TRILIUM_BASE_URL:?TRILIUM_BASE_URL not set}"
: "${TRILIUM_API_TOKEN:?TRILIUM_API_TOKEN not set}"

SKILL="node ./skills/trilium/scripts/trilium.mjs"
STATE_FILE="workflows/state/threads.json"

mkdir -p "$(dirname "$STATE_FILE")"
if [ ! -f "$STATE_FILE" ]; then
  printf '%s\n' '{}' > "$STATE_FILE"
fi

usage() {
  echo "Usage:"
  echo "  $0 start  --thread <key> --title <title> --body <body>"
  echo "  $0 append --thread <key> --text <text>"
  echo "  $0 get    --thread <key>"
  echo "  $0 close  --thread <key> [--delete true]"
  exit 2
}

cmd="${1:-}"
shift || true
if [ -z "$cmd" ]; then usage; fi

thread=""
title=""
body=""
text=""
delete="false"
while [ $# -gt 0 ]; do
  case "$1" in
    --thread) thread="${2:-}"; shift 2 ;;
    --title)  title="${2:-}"; shift 2 ;;
    --body)   body="${2:-}"; shift 2 ;;
    --text)   text="${2:-}"; shift 2 ;;
    --delete) delete="${2:-false}"; shift 2 ;;
    *) usage ;;
  esac
done

if [ -z "$thread" ]; then
  echo '{"ok":false,"message":"--thread is required"}'
  exit 1
fi

get_note_id() {
  python3 -c '
import json,sys
p=sys.argv[1]; key=sys.argv[2]
obj=json.load(open(p,"r",encoding="utf-8"))
v=obj.get(key, {})
nid=v.get("noteId")
print(nid or "")
' "$STATE_FILE" "$thread"
}
set_note_id() {
  python3 -c '
import json,sys
p=sys.argv[1]; key=sys.argv[2]; nid=sys.argv[3]
obj=json.load(open(p,"r",encoding="utf-8"))
obj[key] = {"noteId": nid}
json.dump(obj, open(p,"w",encoding="utf-8"), indent=2)
print()
' "$STATE_FILE" "$thread" "$1"
}
del_thread() {
  python3 -c '
import json,sys
p=sys.argv[1]; key=sys.argv[2]
obj=json.load(open(p,"r",encoding="utf-8"))
obj.pop(key, None)
json.dump(obj, open(p,"w",encoding="utf-8"), indent=2)
print()
' "$STATE_FILE" "$thread"
}

case "$cmd" in
  start)
    if [ -z "$title" ] || [ -z "$body" ]; then
      echo '{"ok":false,"message":"start requires --title and --body"}'
      exit 1
    fi

    existing="$(get_note_id)"
    if [ -n "$existing" ]; then
      echo "{\"ok\":true,\"reused\":true,\"thread\":\"$thread\",\"noteId\":\"$existing\"}"
      exit 0
    fi

    $SKILL ensure-openclaw-root >/dev/null

    create_json="$($SKILL create-log-entry --title "$title" --body "$body")"
    note_id="$(python3 -c '
import json,sys
obj=json.load(sys.stdin)
nid=obj.get("noteId")
if not isinstance(nid,str) or not nid:
    sys.exit(1)
print(nid)
' <<<"$create_json")"
    set_note_id "$note_id" >/dev/null
    echo "{\"ok\":true,\"created\":true,\"thread\":\"$thread\",\"noteId\":\"$note_id\"}"
    ;;

  append)
    if [ -z "$text" ]; then
      echo '{"ok":false,"message":"append requires --text"}'
      exit 1
    fi
    note_id="$(get_note_id)"
    if [ -z "$note_id" ]; then
      echo "{\"ok\":false,\"message\":\"thread not started\",\"thread\":\"$thread\"}"
      exit 1
    fi
    $SKILL append-note --id "$note_id" --text "$text" >/dev/null
    echo "{\"ok\":true,\"thread\":\"$thread\",\"noteId\":\"$note_id\"}"
    ;;

  get)
    note_id="$(get_note_id)"
    if [ -z "$note_id" ]; then
      echo "{\"ok\":false,\"message\":\"thread not started\",\"thread\":\"$thread\"}"
      exit 1
    fi
    $SKILL get-content --id "$note_id"
    ;;

  close)
    note_id="$(get_note_id)"
    if [ -z "$note_id" ]; then
      del_thread >/dev/null
      echo "{\"ok\":true,\"closed\":true,\"thread\":\"$thread\",\"noteId\":null}"
      exit 0
    fi

    if [ "$delete" = "true" ] || [ "$delete" = "1" ] || [ "$delete" = "yes" ]; then
      $SKILL delete-note --id "$note_id" --force >/dev/null || true
    fi

    del_thread >/dev/null
    echo "{\"ok\":true,\"closed\":true,\"thread\":\"$thread\",\"noteId\":\"$note_id\",\"deleted\":$delete}"
    ;;

  *)
    usage
    ;;
esac
