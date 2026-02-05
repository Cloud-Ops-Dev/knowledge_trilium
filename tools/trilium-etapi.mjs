#!/usr/bin/env node
/**
 * TriliumNext ETAPI wrapper for OpenClaw (B5 contract)
 *
 * Env:
 *  - TRILIUM_BASE_URL (e.g. http://127.0.0.1:3011)
 *  - TRILIUM_API_TOKEN (raw token string)
 *
 * Storage (repo-local, gitignored):
 *  - tools/.openclaw-trilium.json  { openclawRootNoteId: "..." }
 *
 * Commands (JSON-only stdout):
 *  - app-info
 *  - print-config
 *  - ensure-openclaw-root [--parent root] [--title "OpenClaw"]
 *  - create-note --parent <id> --title <str> [--type code] [--mime text/x-markdown]
 *  - get-note --id <noteId>
 *  - get-content --id <noteId>                  (GET /etapi/notes/{id}/content)
 *  - set-content --id <noteId> --text <string>  (PUT /etapi/notes/{id}/content, text/plain)
 *  - append-note --id <noteId> --text <string>  (get-content + set-content)
 *  - create-log-entry [--root <noteId>] --title <str> --body <str>
 *  - delete-note --id <noteId> --force
 */

import fs from "node:fs";
import path from "node:path";

const BASE = process.env.TRILIUM_BASE_URL;
const TOKEN = process.env.TRILIUM_API_TOKEN;
const STORE_PATH = path.resolve("tools/.openclaw-trilium.json");

function die(msg, code = 2) { console.error(msg); process.exit(code); }
function requireEnv() {
  if (!BASE) die("Missing env TRILIUM_BASE_URL");
  if (!TOKEN) die("Missing env TRILIUM_API_TOKEN");
}
function stripTrailingSlash(s) { return s.endsWith("/") ? s.slice(0, -1) : s; }

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const k = a.slice(2);
      const v = (i + 1 < argv.length && !argv[i + 1].startsWith("--")) ? argv[++i] : true;
      args[k] = v;
    } else {
      args._.push(a);
    }
  }
  return args;
}

function readStore() {
  try { return JSON.parse(fs.readFileSync(STORE_PATH, "utf-8")); }
  catch { return {}; }
}
function writeStore(obj) {
  fs.mkdirSync(path.dirname(STORE_PATH), { recursive: true });
  fs.writeFileSync(STORE_PATH, JSON.stringify(obj, null, 2) + "\n", "utf-8");
}

function jsonOut(obj) {
  process.stdout.write(JSON.stringify(obj, null, 2) + "\n");
}

async function etapi(pathname, { method = "GET", json = undefined, headers = undefined, body = undefined } = {}) {
  requireEnv();
  const url = `${stripTrailingSlash(BASE)}${pathname}`;
  const h = { "Authorization": TOKEN, ...(headers || {}) };
  let b = body;

  if (json !== undefined) {
    h["Content-Type"] = "application/json";
    b = JSON.stringify(json);
  }

  const res = await fetch(url, { method, headers: h, body: b });
  const text = await res.text();

  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = { raw: text }; }
  }

  if (!res.ok) {
    const msg = (data && (data.message || data.error)) ? (data.message || data.error) : text;
    jsonOut({ ok: false, httpStatus: res.status, path: pathname, message: msg || `HTTP ${res.status}` });
    process.exit(1);
  }

  return { ok: true, httpStatus: res.status, path: pathname, data, rawText: text };
}

function extractNoteIdFromCreate(resp) {
  const d = resp?.data;
  if (d && typeof d === "object") {
    if (typeof d.noteId === "string") return d.noteId;
    if (typeof d.id === "string") return d.id;
    if (d.note && typeof d.note === "object") {
      if (typeof d.note.noteId === "string") return d.note.noteId;
      if (typeof d.note.id === "string") return d.note.id;
    }
  }
  return null;
}

async function cmdAppInfo() {
  const out = await etapi("/etapi/app-info");
  jsonOut(out);
}

async function cmdPrintConfig() {
  const store = readStore();
  jsonOut({
    ok: true,
    baseUrlSet: Boolean(BASE),
    tokenSet: Boolean(TOKEN),
    storePath: STORE_PATH,
    openclawRootNoteId: store.openclawRootNoteId || null
  });
}

async function cmdEnsureOpenClawRoot(args) {
  const store = readStore();
  if (typeof store.openclawRootNoteId === "string" && store.openclawRootNoteId.length > 0) {
    jsonOut({ ok: true, reused: true, openclawRootNoteId: store.openclawRootNoteId });
    return;
  }
  const parent = args.parent || "root";
  const title = args.title || "OpenClaw";
  const out = await etapi("/etapi/create-note", {
    method: "POST",
    json: { parentNoteId: parent, title, type: "text", content: "OpenClaw workspace root." }
  });
  const noteId = extractNoteIdFromCreate(out);
  if (!noteId) {
    jsonOut({ ok: false, message: "Could not extract noteId from create-note response" });
    process.exit(1);
  }
  store.openclawRootNoteId = noteId;
  writeStore(store);
  jsonOut({ ok: true, created: true, openclawRootNoteId: noteId });
}

async function cmdCreateNote(args) {
  const parentNoteId = args.parent || "root";
  const title = args.title;
  const type = args.type || "code";
  const mime = args.mime || (type === "code" ? "text/x-markdown" : undefined);
  if (!title) die("create-note requires --title <string>");
  const body = { parentNoteId, title, type, content: "" };
  if (mime) body.mime = mime;
  const out = await etapi("/etapi/create-note", { method: "POST", json: body });
  jsonOut(out);
}

async function cmdGetNote(args) {
  const id = args.id;
  if (!id) die("get-note requires --id <noteId>");
  const out = await etapi(`/etapi/notes/${encodeURIComponent(id)}`);
  jsonOut(out);
}

async function cmdGetContent(args) {
  const id = args.id;
  if (!id) die("get-content requires --id <noteId>");
  const res = await etapi(`/etapi/notes/${encodeURIComponent(id)}/content`);
  jsonOut({ ok: true, httpStatus: res.httpStatus, path: res.path, content: res.rawText || "" });
}

async function cmdSetContent(args) {
  const id = args.id;
  const text = args.text;
  if (!id) die("set-content requires --id <noteId>");
  if (!text || text === true) die("set-content requires --text <string>");
  const out = await etapi(`/etapi/notes/${encodeURIComponent(id)}/content`, {
    method: "PUT",
    headers: { "Content-Type": "text/plain; charset=utf-8" },
    body: String(text)
  });
  jsonOut({ ok: true, httpStatus: out.httpStatus, path: out.path });
}

async function cmdAppendNote(args) {
  const id = args.id;
  const text = args.text;
  if (!id) die("append-note requires --id <noteId>");
  if (!text || text === true) die("append-note requires --text <string>");

  const current = await etapi(`/etapi/notes/${encodeURIComponent(id)}/content`);
  const existing = current.rawText || "";
  const sep = existing.length ? "\n\n" : "";
  const next = `${existing}${sep}${text}`;

  const updated = await etapi(`/etapi/notes/${encodeURIComponent(id)}/content`, {
    method: "PUT",
    headers: { "Content-Type": "text/plain; charset=utf-8" },
    body: next
  });

  jsonOut({ ok: true, httpStatus: updated.httpStatus, path: updated.path });
}

async function cmdCreateLogEntry(args) {
  const store = readStore();
  const root = args.root || store.openclawRootNoteId;
  const title = args.title;
  const body = args.body;

  if (!root) die("create-log-entry requires --root <noteId> or prior ensure-openclaw-root");
  if (!title) die("create-log-entry requires --title <string>");
  if (!body || body === true) die("create-log-entry requires --body <string>");

  const created = await etapi("/etapi/create-note", { method: "POST", json: { parentNoteId: root, title, type: "code", mime: "text/x-markdown", content: "" } });
  const noteId = extractNoteIdFromCreate(created);
  if (!noteId) {
    jsonOut({ ok: false, message: "Could not extract noteId from create-note response" });
    process.exit(1);
  }

  await etapi(`/etapi/notes/${encodeURIComponent(noteId)}/content`, {
    method: "PUT",
    headers: { "Content-Type": "text/plain; charset=utf-8" },
    body: String(body)
  });

  jsonOut({ ok: true, created: true, noteId, parentNoteId: root, title });
}

async function cmdDeleteNote(args) {
  const id = args.id;
  const force = args.force === true || args.force === "true";
  if (!id) die("delete-note requires --id <noteId>");
  if (!force) die("Refusing to delete without --force");
  const out = await etapi(`/etapi/notes/${encodeURIComponent(id)}`, { method: "DELETE" });
  jsonOut({ ok: true, httpStatus: out.httpStatus, path: out.path });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0];

  if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
    jsonOut({
      ok: true,
      usage: [
        "trilium-etapi.mjs app-info",
        "trilium-etapi.mjs print-config",
        "trilium-etapi.mjs ensure-openclaw-root [--parent root] [--title \"OpenClaw\"]",
        "trilium-etapi.mjs create-note --parent <id> --title \"...\" [--type code] [--mime text/x-markdown]",
        "trilium-etapi.mjs get-note --id <noteId>",
        "trilium-etapi.mjs get-content --id <noteId>",
        "trilium-etapi.mjs set-content --id <noteId> --text \"...\"",
        "trilium-etapi.mjs append-note --id <noteId> --text \"...\"",
        "trilium-etapi.mjs create-log-entry [--root <noteId>] --title \"...\" --body \"...\"",
        "trilium-etapi.mjs delete-note --id <noteId> --force"
      ],
      store: "tools/.openclaw-trilium.json (gitignored)"
    });
    return;
  }

  switch (cmd) {
    case "app-info": return cmdAppInfo();
    case "print-config": return cmdPrintConfig();
    case "ensure-openclaw-root": return cmdEnsureOpenClawRoot(args);
    case "create-note": return cmdCreateNote(args);
    case "get-note": return cmdGetNote(args);
    case "get-content": return cmdGetContent(args);
    case "set-content": return cmdSetContent(args);
    case "append-note": return cmdAppendNote(args);
    case "create-log-entry": return cmdCreateLogEntry(args);
    case "delete-note": return cmdDeleteNote(args);
    default: die(`Unknown command: ${cmd}`);
  }
}

main().catch(err => {
  jsonOut({ ok: false, message: err?.message || String(err) });
  process.exit(1);
});
