#!/usr/bin/env bash
set -euo pipefail

: "${TRILIUM_BASE_URL:?TRILIUM_BASE_URL not set}"
: "${TRILIUM_API_TOKEN:?TRILIUM_API_TOKEN not set}"

SKILL="node ./skills/trilium/scripts/trilium.mjs"
STATE_FILE="workflows/state/threads.json"

# --- OPENCLAW_THREAD_POINTERS_V1 ---
STATE_DIR="${STATE_DIR:-workflows/state}"
LAST_THREAD_FILE="${LAST_THREAD_FILE:-$STATE_DIR/last_thread.json}"

ensure_state_dir() { mkdir -p "$STATE_DIR"; }

read_pointer_json() {
  if [ -f "$LAST_THREAD_FILE" ]; then
    cat "$LAST_THREAD_FILE"
  else
    echo "{}"
  fi
}

write_pointer_json() {
  ensure_state_dir
  local tmp="$LAST_THREAD_FILE.tmp"
  cat > "$tmp"
  mv "$tmp" "$LAST_THREAD_FILE"
}

pointer_get() {
  local jq_expr="$1"
  read_pointer_json | jq -r "$jq_expr // empty"
}

resolve_latest_thread_key() {
  local prefer_active="$1"
  local source="$2"
  local channel="$3"
  local guild="$4"
  local k=""

  if [ "$prefer_active" = "true" ]; then
    k="$(pointer_get '.active')"
    if [ -n "$k" ]; then echo "$k"; return 0; fi
  fi

  if [ -n "$channel" ]; then
    k="$(read_pointer_json | jq -r --arg ch "$channel" '.["discord:channel:" + $ch] // empty')"
    if [ -n "$k" ]; then echo "$k"; return 0; fi
  fi

  if [ -n "$guild" ]; then
    k="$(read_pointer_json | jq -r --arg g "$guild" '.["discord:guild:" + $g] // empty')"
    if [ -n "$k" ]; then echo "$k"; return 0; fi
  fi

  if [ "$source" = "discord" ]; then
    k="$(pointer_get '.["discord:last"]')"
    if [ -n "$k" ]; then echo "$k"; return 0; fi
  fi

  k="$(pointer_get '.["global:last"]')"
  if [ -n "$k" ]; then echo "$k"; return 0; fi

  return 1
}
# --- /OPENCLAW_THREAD_POINTERS_V1 ---

# --- POINTER COMMANDS (must be before main dispatch) ---
if [ "${1:-}" = "get-latest" ]; then
  shift
  prefer_active="true"
  source=""
  channel=""
  guild=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --prefer-active) prefer_active="${2:-true}"; shift 2 ;;
      --source) source="${2:-}"; shift 2 ;;
      --channel) channel="${2:-}"; shift 2 ;;
      --guild) guild="${2:-}"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
  done

  key="$(resolve_latest_thread_key "$prefer_active" "$source" "$channel" "$guild" || true)"
  if [ -z "${key:-}" ]; then
    echo "No last thread known yet." >&2
    exit 1
  fi
  echo "$key"
  exit 0
fi

if [ "${1:-}" = "set-active" ]; then
  shift
  thread=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --thread) thread="${2:-}"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
  done
  if [ -z "$thread" ]; then
    echo "Missing --thread KEY" >&2
    exit 2
  fi
  ensure_state_dir
  now="$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.datetime.now().astimezone().tzinfo).replace(microsecond=0).isoformat())')"
  read_pointer_json | jq --arg t "$thread" --arg now "$now" '.active=$t | .active_set_at=$now | .updated_at=$now' | write_pointer_json
  exit 0
fi

if [ "${1:-}" = "clear-active" ]; then
  read_pointer_json | jq 'del(.active) | del(.active_set_at)' | write_pointer_json
  exit 0
fi

if [ "${1:-}" = "status" ]; then
  read_pointer_json | jq -r '"active=" + (.active // "") + "\nglobal:last=" + (.["global:last"] // "") + "\ndiscord:last=" + (.["discord:last"] // "") + "\nupdated_at=" + (.updated_at // "")'
  exit 0
fi
# --- /POINTER COMMANDS ---

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
  echo "  $0 get-latest [--source discord] [--channel ID] [--guild ID]"
  echo "  $0 set-active --thread <key>"
  echo "  $0 clear-active"
  echo "  $0 status"
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
