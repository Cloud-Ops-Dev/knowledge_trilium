#!/usr/bin/env bash
# File Manager integration test for trilium-etapi.mjs
# Tests: resolve-path, search-notes, list-children, rename-note, move-note, create-folder, --path support
set -euo pipefail

: "${TRILIUM_BASE_URL:?Missing TRILIUM_BASE_URL}"
: "${TRILIUM_API_TOKEN:?Missing TRILIUM_API_TOKEN}"

PASS=0
FAIL=0
CLEANUP_IDS=()

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
cleanup() {
  echo ""
  echo "--- Cleanup ---"
  for nid in "${CLEANUP_IDS[@]}"; do
    node ./tools/trilium-etapi.mjs delete-note --id "$nid" --force >/dev/null 2>&1 || true
  done
  echo "Cleaned up ${#CLEANUP_IDS[@]} notes"
}
trap cleanup EXIT

extract_id() {
  python3 -c '
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
nid=getid(d) or obj.get("noteId")
if not nid: sys.exit(1)
print(nid)
'
}

# Ensure OpenClaw root exists
node ./tools/trilium-etapi.mjs ensure-openclaw-root >/dev/null
ROOT_ID="$(node ./tools/trilium-etapi.mjs print-config | python3 -c 'import json,sys; print(json.load(sys.stdin)["openclawRootNoteId"])')"

echo "=== File Manager Tests ==="
echo "OpenClaw root: $ROOT_ID"
echo ""

# 1. Create test folder
echo "--- Setup: Create test folder ---"
FOLDER_JSON="$(node ./tools/trilium-etapi.mjs create-folder --parent "$ROOT_ID" --title "FM-Test-$(date +%s)")"
FOLDER_ID="$(echo "$FOLDER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["noteId"])')"
CLEANUP_IDS+=("$FOLDER_ID")
FOLDER_TITLE="$(echo "$FOLDER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["title"])')"
echo "  Created folder: $FOLDER_TITLE ($FOLDER_ID)"

# 2. Create child notes + subfolder
CHILD1_JSON="$(node ./tools/trilium-etapi.mjs create-note --parent "$FOLDER_ID" --title "Child-Alpha")"
CHILD1_ID="$(echo "$CHILD1_JSON" | extract_id)"
CLEANUP_IDS+=("$CHILD1_ID")

CHILD2_JSON="$(node ./tools/trilium-etapi.mjs create-note --parent "$FOLDER_ID" --title "Child-Beta")"
CHILD2_ID="$(echo "$CHILD2_JSON" | extract_id)"
CLEANUP_IDS+=("$CHILD2_ID")

SUBFOLDER_JSON="$(node ./tools/trilium-etapi.mjs create-folder --parent "$FOLDER_ID" --title "SubFolder")"
SUBFOLDER_ID="$(echo "$SUBFOLDER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["noteId"])')"
CLEANUP_IDS+=("$SUBFOLDER_ID")
echo "  Created children: Child-Alpha, Child-Beta, SubFolder"
echo ""

# 3. Test resolve-path
echo "--- Test: resolve-path ---"
RESOLVE_JSON="$(node ./tools/trilium-etapi.mjs resolve-path --path "$FOLDER_TITLE")"
RESOLVED_ID="$(echo "$RESOLVE_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["noteId"])')"
if [ "$RESOLVED_ID" = "$FOLDER_ID" ]; then
  pass "resolve-path found test folder"
else
  fail "resolve-path returned $RESOLVED_ID, expected $FOLDER_ID"
fi

# 3b. Resolve nested path
NESTED_JSON="$(node ./tools/trilium-etapi.mjs resolve-path --path "$FOLDER_TITLE/SubFolder")"
NESTED_ID="$(echo "$NESTED_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["noteId"])')"
if [ "$NESTED_ID" = "$SUBFOLDER_ID" ]; then
  pass "resolve-path found nested subfolder"
else
  fail "resolve-path nested returned $NESTED_ID, expected $SUBFOLDER_ID"
fi

# 4. Test search-notes
echo "--- Test: search-notes ---"
SEARCH_JSON="$(node ./tools/trilium-etapi.mjs search-notes --query "$FOLDER_TITLE")"
SEARCH_COUNT="$(echo "$SEARCH_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
if [ "$SEARCH_COUNT" -ge 1 ]; then
  pass "search-notes found $SEARCH_COUNT result(s)"
else
  fail "search-notes found 0 results for $FOLDER_TITLE"
fi

# 5. Test list-children
echo "--- Test: list-children ---"
LIST_JSON="$(node ./tools/trilium-etapi.mjs list-children --id "$FOLDER_ID")"
LIST_COUNT="$(echo "$LIST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
if [ "$LIST_COUNT" -eq 3 ]; then
  pass "list-children shows 3 children"
else
  fail "list-children shows $LIST_COUNT, expected 3"
fi

# 5b. list-children via --path
LIST2_JSON="$(node ./tools/trilium-etapi.mjs list-children --path "$FOLDER_TITLE")"
LIST2_COUNT="$(echo "$LIST2_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
if [ "$LIST2_COUNT" -eq 3 ]; then
  pass "list-children via --path works"
else
  fail "list-children via --path shows $LIST2_COUNT, expected 3"
fi

# 6. Test rename-note
echo "--- Test: rename-note ---"
node ./tools/trilium-etapi.mjs rename-note --id "$CHILD1_ID" --title "Child-Alpha-Renamed" >/dev/null
RENAMED_JSON="$(node ./tools/trilium-etapi.mjs get-note --id "$CHILD1_ID")"
RENAMED_TITLE="$(echo "$RENAMED_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["title"])')"
if [ "$RENAMED_TITLE" = "Child-Alpha-Renamed" ]; then
  pass "rename-note updated title"
else
  fail "rename-note title is '$RENAMED_TITLE', expected 'Child-Alpha-Renamed'"
fi

# 7. Test move-note (move Child-Beta into SubFolder)
echo "--- Test: move-note ---"
node ./tools/trilium-etapi.mjs move-note --id "$CHILD2_ID" --to "$SUBFOLDER_ID" >/dev/null

# Verify parent now has 2 children
LIST3_JSON="$(node ./tools/trilium-etapi.mjs list-children --id "$FOLDER_ID")"
LIST3_COUNT="$(echo "$LIST3_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
if [ "$LIST3_COUNT" -eq 2 ]; then
  pass "move-note: parent now has 2 children (was 3)"
else
  fail "move-note: parent has $LIST3_COUNT children, expected 2"
fi

# Verify subfolder now has 1 child
LIST4_JSON="$(node ./tools/trilium-etapi.mjs list-children --id "$SUBFOLDER_ID")"
LIST4_COUNT="$(echo "$LIST4_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"
if [ "$LIST4_COUNT" -eq 1 ]; then
  pass "move-note: subfolder now has 1 child"
else
  fail "move-note: subfolder has $LIST4_COUNT children, expected 1"
fi

# 8. Test create-folder via --parent-path
echo "--- Test: create-folder via --parent-path ---"
SUBFOLDER2_JSON="$(node ./tools/trilium-etapi.mjs create-folder --parent-path "$FOLDER_TITLE" --title "SubFolder2")"
SUBFOLDER2_ID="$(echo "$SUBFOLDER2_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["noteId"])')"
CLEANUP_IDS+=("$SUBFOLDER2_ID")
if [ -n "$SUBFOLDER2_ID" ]; then
  pass "create-folder via --parent-path created note"
else
  fail "create-folder via --parent-path failed"
fi

# 9. Test get-content via --path
echo "--- Test: get-content via --path ---"
node ./tools/trilium-etapi.mjs set-content --id "$CHILD1_ID" --text "path-test-content" >/dev/null
CONTENT_JSON="$(node ./tools/trilium-etapi.mjs get-content --path "$FOLDER_TITLE/Child-Alpha-Renamed")"
CONTENT="$(echo "$CONTENT_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["content"])')"
if [ "$CONTENT" = "path-test-content" ]; then
  pass "get-content via --path works"
else
  fail "get-content via --path returned '$CONTENT', expected 'path-test-content'"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
