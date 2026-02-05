#!/usr/bin/env bash
set -euo pipefail

: "${TRILIUM_BASE_URL:?TRILIUM_BASE_URL not set}"
: "${TRILIUM_API_TOKEN:?TRILIUM_API_TOKEN not set}"

STATE_DEFAULTS="workflows/state/intake_defaults.json"
TEMPLATE="workflows/templates/intake.md"
THREAD_TOOL="./workflows/c2_trilium_thread.sh"

cmd="${1:-}"
shift || true

usage() {
  echo "Usage:"
  echo "  $0 start  --thread <key> --title <title> --summary <text> [--source <src>] [--context <text>] [--signals <text>] [--actions <text>] [--links <text>]"
  echo "  $0 append --thread <key> --who <name> --text <text>"
  exit 2
}

thread=""
title=""
summary=""
source=""
context=""
signals=""
actions=""
links=""
who=""
text=""

while [ $# -gt 0 ]; do
  case "$1" in
    start|append) cmd="$1"; shift ;;
    --thread) thread="${2:-}"; shift 2 ;;
    --title) title="${2:-}"; shift 2 ;;
    --summary) summary="${2:-}"; shift 2 ;;
    --source) source="${2:-}"; shift 2 ;;
    --context) context="${2:-}"; shift 2 ;;
    --signals) signals="${2:-}"; shift 2 ;;
    --actions) actions="${2:-}"; shift 2 ;;
    --links) links="${2:-}"; shift 2 ;;
    --who) who="${2:-}"; shift 2 ;;
    --text) text="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done

if [ -z "$cmd" ]; then usage; fi
if [ -z "$thread" ]; then echo '{"ok":false,"message":"--thread is required"}'; exit 1; fi

default_source="local"
default_signals="None yet"
default_actions="Triage and classify"
default_links="- (none)"
if [ -f "$STATE_DEFAULTS" ]; then
  eval "$(python3 -c '
import json,sys,shlex
obj=json.load(open(sys.argv[1],"r",encoding="utf-8"))
def p(k,default):
    v=obj.get(k,default)
    print(f"def_{k}={shlex.quote(str(v))}")
p("source","local")
p("signals","None yet")
p("actions","Triage and classify")
p("links","- (none)")
' "$STATE_DEFAULTS")"
  default_source="${def_source:-$default_source}"
  default_signals="${def_signals:-$default_signals}"
  default_actions="${def_actions:-$default_actions}"
  default_links="${def_links:-$default_links}"
fi

created_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

render_intake() {
  python3 -c '
import sys
tpl_path=sys.argv[1]
vals={
 "THREAD_KEY": sys.argv[2],
 "SOURCE": sys.argv[3],
 "CREATED_UTC": sys.argv[4],
 "SUMMARY": sys.argv[5],
 "CONTEXT": sys.argv[6],
 "SIGNALS": sys.argv[7],
 "ACTIONS": sys.argv[8],
 "LINKS": sys.argv[9],
}
tpl=open(tpl_path,"r",encoding="utf-8").read()
for k,v in vals.items():
    tpl=tpl.replace("{{"+k+"}}", v if v else "")
print(tpl)
' "$TEMPLATE" "$thread" "$source" "$created_utc" "$summary" "$context" "$signals" "$actions" "$links"
}

case "$cmd" in
  start)
    if [ -z "$title" ] || [ -z "$summary" ]; then
      echo '{"ok":false,"message":"start requires --title and --summary"}'
      exit 1
    fi

    source="${source:-$default_source}"
    signals="${signals:-$default_signals}"
    actions="${actions:-$default_actions}"
    links="${links:-$default_links}"
    context="${context:-}"

    body="$(render_intake)"

    out="$($THREAD_TOOL start --thread "$thread" --title "$title" --body "$body")"
    echo "$out"
    ;;

  append)
    if [ -z "$text" ]; then
      echo '{"ok":false,"message":"append requires --text"}'
      exit 1
    fi
    who="${who:-user}"
    stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    entry="- ${stamp} — ${who}: ${text}"
    $THREAD_TOOL append --thread "$thread" --text "$entry" >/dev/null
    echo "{\"ok\":true,\"thread\":\"$thread\",\"appended\":true}"
    ;;

  *)
    usage
    ;;
esac
