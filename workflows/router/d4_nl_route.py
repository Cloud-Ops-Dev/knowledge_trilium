#!/usr/bin/env python3
import json, os, re, sys, subprocess, pathlib
from typing import Dict, Any, Tuple, Optional

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
C2 = REPO_ROOT / "workflows" / "c2_trilium_thread.sh"
TRILIUM_SKILL = REPO_ROOT / "skills" / "trilium" / "scripts" / "trilium.mjs"

def run(cmd, *, input_text: Optional[str]=None) -> Tuple[int, str, str]:
    p = subprocess.run(
        cmd,
        input=input_text,
        text=True,
        capture_output=True,
        cwd=str(REPO_ROOT),
        env=os.environ.copy(),
    )
    return p.returncode, p.stdout.strip(), p.stderr.strip()

def c2_get_latest(source="discord", channel=None, guild=None, prefer_active=True) -> str:
    cmd = [str(C2), "get-latest", "--source", source, "--prefer-active", "true" if prefer_active else "false"]
    if channel:
        cmd += ["--channel", str(channel)]
    if guild:
        cmd += ["--guild", str(guild)]
    rc, out, err = run(cmd)
    if rc != 0 or not out:
        raise RuntimeError(err or "No last thread known yet")
    return out

def c2_set_active(thread_key: str) -> None:
    rc, out, err = run([str(C2), "set-active", "--thread", thread_key])
    if rc != 0:
        raise RuntimeError(err or out or "Failed to set active")

def trilium_get_content(note_id: str) -> str:
    rc, out, err = run(["node", str(TRILIUM_SKILL), "get-content", "--id", note_id])
    if rc != 0:
        raise RuntimeError(err or out or "Failed to get content")
    # Parse JSON response to get content field
    try:
        obj = json.loads(out)
        return obj.get("content", "")
    except:
        return out

def trilium_append(note_id: str, text: str) -> None:
    rc, out, err = run(["node", str(TRILIUM_SKILL), "append-note", "--id", note_id, "--text", text])
    if rc != 0:
        raise RuntimeError(err or out or "Failed to append")

def c2_get_thread(thread_key: str) -> Dict[str, Any]:
    state = REPO_ROOT / "workflows" / "state" / "threads.json"
    if state.exists():
        try:
            data = json.loads(state.read_text(encoding="utf-8"))
            meta = data.get(thread_key) or {}
            nid = meta.get("noteId") or meta.get("note_id")
            if nid:
                return {"threadKey": thread_key, "noteId": nid, "meta": meta}
        except Exception:
            pass

    rc, out, err = run([str(C2), "get", "--thread", thread_key])
    if rc == 0:
        try:
            o = json.loads(out)
            nid = o.get("noteId") or o.get("note_id")
            if nid:
                return {"threadKey": thread_key, "noteId": nid, "meta": o}
        except Exception:
            pass
    raise RuntimeError("Could not resolve noteId for thread")

def detect_intent(utterance: str) -> str:
    u = utterance.strip().lower()

    if re.search(r'\b(show|open|fetch|get|display|pull)\b', u) and re.search(r'\b(last|latest|active)\b', u):
        return "show_thread"
    if re.search(r'\blast\b', u) and re.search(r'\bdiscord\b', u):
        return "show_thread"
    if re.search(r'\bactive\b', u) and re.search(r'\bthread\b', u):
        return "show_thread"


# --- OPENCLAW_TIMESTAMPED_APPEND_V1 ---
def format_timestamped_append(text: str, tag: str = "via OpenClaw") -> str:
    import datetime
    now = datetime.datetime.now(datetime.datetime.now().astimezone().tzinfo).replace(microsecond=0).isoformat()
    return f"\n\n---\n[{now}] ({tag})\n{text.strip()}\n"
# --- /OPENCLAW_TIMESTAMPED_APPEND_V1 ---

    if re.search(r'\b(append|add|log|note|save)\b', u):
        return "append"
    if re.search(r'\b(add this|append this|put this)\b', u):
        return "append"

    if re.search(r'\b(summarize|summary)\b', u) or re.search(r'\b(decisions|next steps|action items)\b', u):
        return "summarize"

    if re.search(r'\b(last convo|last conversation|that thread|that convo)\b', u):
        return "show_thread"

    return "unknown"

def extract_scope(utterance: str) -> Dict[str, Optional[str]]:
    u = utterance.lower()
    m_ch = re.search(r'\bchannel\s+(\d+)\b', u)
    m_g = re.search(r'\bguild\s+(\d+)\b', u)
    return {"channel": m_ch.group(1) if m_ch else None, "guild": m_g.group(1) if m_g else None}

def build_summary_stub(content: str) -> Dict[str, Any]:
    lines = [l.rstrip() for l in content.splitlines()]
    actions = [l for l in lines if re.search(r'^\s*(action|todo|next)\s*[:\-]', l, re.I)]
    decisions = [l for l in lines if re.search(r'^\s*(decision)\s*[:\-]', l, re.I)]
    risks = [l for l in lines if re.search(r'^\s*(risk|blocker)\s*[:\-]', l, re.I)]
    return {
        "summary": "",
        "decisions": decisions[:20],
        "actions": actions[:50],
        "risks": risks[:20],
        "notes": "Router produced a stub. For a full NL summary, have OpenClaw run an LLM pass over content."
    }

def main():
    raw = sys.stdin.read()
    if not raw.strip():
        print(json.dumps({"ok": False, "message": "No input. Provide JSON on stdin."}, indent=2))
        raise SystemExit(2)

    try:
        req = json.loads(raw)
    except Exception as e:
        print(json.dumps({"ok": False, "message": f"Invalid JSON input: {e}"}, indent=2))
        raise SystemExit(2)

    utterance = str(req.get("utterance") or "").strip()
    payload_text = str(req.get("text") or "").strip()
    source = str(req.get("source") or "discord").strip().lower()

    if not utterance:
        print(json.dumps({"ok": False, "message": "Missing required field: utterance"}, indent=2))
        raise SystemExit(2)

    intent = detect_intent(utterance)
    scope = extract_scope(utterance)

    try:
        thread_key = c2_get_latest(source=source, channel=scope["channel"], guild=scope["guild"], prefer_active=True)
        c2_set_active(thread_key)

        meta = c2_get_thread(thread_key)
        note_id = meta["noteId"]

        if intent == "show_thread":
            content = trilium_get_content(note_id)
            out = {
                "ok": True,
                "intent": intent,
                "source": source,
                "threadKey": thread_key,
                "noteId": note_id,
                "content": content
            }
            print(json.dumps(out, indent=2))
            return

        if intent == "append":
            if not payload_text:
                print(json.dumps({"ok": False, "intent": intent, "message": "Append intent requires 'text' field"}, indent=2))
                return
            trilium_append(note_id, format_timestamped_append(payload_text))out = {
                "ok": True,
                "intent": intent,
                "source": source,
                "threadKey": thread_key,
                "noteId": note_id,
                "appended": True,
                "bytes": len(payload_text.encode("utf-8"))
            }
            print(json.dumps(out, indent=2))
            return

        if intent == "summarize":
            content = trilium_get_content(note_id)
            stub = build_summary_stub(content)
            out = {
                "ok": True,
                "intent": intent,
                "source": source,
                "threadKey": thread_key,
                "noteId": note_id,
                "summary_stub": stub
            }
            print(json.dumps(out, indent=2))
            return

        print(json.dumps({
            "ok": False,
            "intent": intent,
            "message": "Could not confidently route utterance. Try: 'show last discord thread', 'append this', or 'summarize decisions'.",
            "hints": {
                "utterance": utterance,
                "expected_input": {"utterance": "...", "text": "(optional for append)", "source": "discord"}
            }
        }, indent=2))

    except Exception as e:
        print(json.dumps({"ok": False, "message": str(e), "intent": intent}, indent=2))
        raise SystemExit(1)

if __name__ == "__main__":
    main()
