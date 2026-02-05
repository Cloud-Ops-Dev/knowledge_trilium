#!/usr/bin/env python3
import json, os, sys, pathlib, subprocess, datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
D1 = REPO_ROOT / "workflows" / "ingest" / "d1_discord_ingest.py"
LOG_PATH = REPO_ROOT / "tmp" / "discord_events.jsonl"

HOST = os.environ.get("D2_HOST", "127.0.0.1")
PORT = int(os.environ.get("D2_PORT", "8787"))

def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def run_d1(payload: dict) -> dict:
    p = subprocess.run(
        [sys.executable, str(D1)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        cwd=str(REPO_ROOT),
        env=os.environ
    )
    if p.returncode != 0:
        try:
            return json.loads(p.stdout) if p.stdout.strip() else {"ok": False, "message": p.stderr.strip() or "D1 failed"}
        except Exception:
            return {"ok": False, "message": p.stderr.strip() or "D1 failed", "raw": p.stdout.strip()}
    try:
        return json.loads(p.stdout)
    except Exception:
        return {"ok": False, "message": "D1 returned non-JSON output", "raw": p.stdout.strip()}

def normalize_discord(payload: dict) -> dict:
    if "message" in payload and isinstance(payload["message"], dict):
        payload = payload["message"]

    if any(k in payload for k in ("channel_id", "message_id")):
        return payload

    out = {}
    out["message_id"] = str(payload.get("id") or payload.get("messageId") or "")
    out["channel_id"] = str(payload.get("channelId") or payload.get("channel_id") or "")
    out["guild_id"] = str(payload.get("guildId") or payload.get("guild_id") or "")
    out["content"] = str(payload.get("content") or payload.get("message") or "")

    author = payload.get("author")
    if isinstance(author, dict):
        out["author"] = str(author.get("username") or author.get("name") or "unknown")
    else:
        out["author"] = str(payload.get("username") or payload.get("user") or "unknown")

    out["jump_url"] = str(payload.get("url") or payload.get("jump_url") or "")

    ref = payload.get("reference")
    root = payload.get("rootMessageId") or payload.get("root_message_id")
    if root:
        out["root_message_id"] = str(root)
    elif isinstance(ref, dict) and ref.get("messageId"):
        out["root_message_id"] = str(ref["messageId"])
    else:
        out["root_message_id"] = out["message_id"]

    return out

class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, obj: dict):
        b = json.dumps(obj, indent=2).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_POST(self):
        if self.path not in ("/discord", "/discord/ingest"):
            self._send(404, {"ok": False, "message": f"unknown path {self.path}"})
            return

        n = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(n).decode("utf-8", errors="replace")

        try:
            payload = json.loads(raw) if raw.strip() else {}
        except Exception as e:
            self._send(400, {"ok": False, "message": f"invalid JSON: {e}"})
            return

        norm = normalize_discord(payload)
        norm["_receivedUtc"] = utc_now()

        try:
            LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
            with open(LOG_PATH, "a", encoding="utf-8") as f:
                f.write(json.dumps(norm) + "\n")
        except Exception:
            pass

        resp = run_d1(norm)
        code = 200 if resp.get("ok") else 500
        self._send(code, resp)

    def log_message(self, fmt, *args):
        return

def main():
    if not D1.exists():
        print(json.dumps({"ok": False, "message": f"Missing {D1}"}))
        raise SystemExit(2)

    srv = HTTPServer((HOST, PORT), Handler)
    print(json.dumps({
        "ok": True,
        "listening": True,
        "host": HOST,
        "port": PORT,
        "endpoint": f"http://{HOST}:{PORT}/discord"
    }, indent=2))
    sys.stdout.flush()
    srv.serve_forever()

if __name__ == "__main__":
    main()
