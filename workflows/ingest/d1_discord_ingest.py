#!/usr/bin/env python3
import json, os, sys, datetime, pathlib, subprocess

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# --- OPENCLAW_LAST_THREAD_POINTERS_V1 ---
_LAST_THREAD_PATH = REPO_ROOT / "workflows" / "state" / "last_thread.json"

def _iso_now_local():
    return datetime.datetime.now(datetime.datetime.now().astimezone().tzinfo).replace(microsecond=0).isoformat()

def _load_pointer_json():
    try:
        if not _LAST_THREAD_PATH.exists():
            return {}
        return json.loads(_LAST_THREAD_PATH.read_text(encoding="utf-8") or "{}")
    except Exception:
        return {}

def _atomic_write_json(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(obj, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, path)

def update_last_thread_pointers(thread_key: str, guild_id: str = "", channel_id: str = "", source: str = "discord"):
    data = _load_pointer_json()
    data["global:last"] = thread_key
    if source == "discord":
        data["discord:last"] = thread_key
        if channel_id:
            data[f"discord:channel:{channel_id}"] = thread_key
        if guild_id:
            data[f"discord:guild:{guild_id}"] = thread_key
    data["updated_at"] = _iso_now_local()
    _atomic_write_json(_LAST_THREAD_PATH, data)
# --- /OPENCLAW_LAST_THREAD_POINTERS_V1 ---
THREADS_FILE = REPO_ROOT / "workflows" / "state" / "threads.json"
C4 = REPO_ROOT / "workflows" / "c4_trilium_intake.sh"
C2 = REPO_ROOT / "workflows" / "c2_trilium_thread.sh"

def die(msg: str, code: int = 2):
    sys.stdout.write(json.dumps({"ok": False, "message": msg}, indent=2) + "\n")
    raise SystemExit(code)

def utc_now():
    # timezone-aware UTC to avoid datetime.utcnow() deprecation warnings
    return datetime.datetime.now(datetime.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def load_threads():
    if not THREADS_FILE.exists():
        return {}
    try:
        return json.loads(THREADS_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}

def thread_exists(key: str) -> bool:
    obj = load_threads()
    v = obj.get(key, {})
    return isinstance(v, dict) and isinstance(v.get("noteId"), str) and len(v["noteId"]) > 0

def run(cmd, capture=True):
    p = subprocess.run(cmd, cwd=str(REPO_ROOT), text=True,
                       capture_output=capture, env=os.environ)
    if p.returncode != 0:
        die(f"Command failed: {' '.join(cmd)} | stderr: {p.stderr.strip()}")
    return p.stdout.strip() if capture else ""

def main():
    raw = sys.stdin.read()
    if not raw.strip():
        die("No input JSON on stdin")

    try:
        payload = json.loads(raw)
    except Exception as e:
        die(f"Invalid JSON: {e}")

    guild_id   = str(payload.get("guild_id") or payload.get("guildId") or "")
    channel_id = str(payload.get("channel_id") or payload.get("channelId") or "")
    message_id = str(payload.get("message_id") or payload.get("messageId") or "")
    author     = str(payload.get("author") or payload.get("username") or payload.get("user") or "unknown")
    content    = str(payload.get("content") or payload.get("message") or "")
    jump_url   = str(payload.get("jump_url") or payload.get("url") or "")
    root_id    = str(payload.get("root_message_id") or payload.get("rootMessageId") or message_id)

    if not channel_id or not message_id:
        die("Missing required fields: channel_id and message_id")

    thread_key = f"discord:{guild_id}:{channel_id}:{root_id}"

    created = False
    note_id = None

    if not thread_exists(thread_key):
        title = f"Intake: Discord {channel_id} ({utc_now()})"
        summary = (content[:140] + "…") if len(content) > 140 else content
        source = "discord"

        ctx_lines = []
        ctx_lines.append(f"Channel: {channel_id}")
        if guild_id:
            ctx_lines.append(f"Guild: {guild_id}")
        ctx_lines.append(f"Message ID: {message_id}")
        if jump_url:
            ctx_lines.append(f"Jump URL: {jump_url}")
        ctx_lines.append("")
        ctx_lines.append("Initial Message")
        ctx_lines.append(f"{author}: {content}")

        context = "\n".join(ctx_lines)

        out = run([str(C4), "start",
                   "--thread", thread_key,
                   "--title", title,
                   "--summary", summary if summary else "(no content)",
                   "--source", source,
                   "--context", context])

        try:
            obj = json.loads(out)
        except Exception:
            die("C4 start returned non-JSON output")
        note_id = obj.get("noteId")
        created = True

    should_append = (message_id != root_id)
    if payload.get("force_append") is True:
        should_append = True

    if should_append and content:
        who = author or "user"
        text = content if len(content) <= 500 else (content[:500] + "…")
        run([str(C4), "append",
             "--thread", thread_key,
             "--who", who,
             "--text", text], capture=True)

    # Update last-thread pointers (best-effort)
    try:
        update_last_thread_pointers(thread_key, guild_id=guild_id, channel_id=channel_id, source="discord")
    except Exception:
        pass

    sys.stdout.write(json.dumps({
        "ok": True,
        "threadKey": thread_key,
        "created": created,
        "noteId": note_id
    }, indent=2) + "\n")

if __name__ == "__main__":
    main()
