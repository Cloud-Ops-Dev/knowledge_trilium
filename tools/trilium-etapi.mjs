#!/usr/bin/env node
/**
 * TriliumNext ETAPI wrapper for OpenClaw (B5 + FM contract)
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
 *  - get-note --id <noteId> | --path <path>
 *  - get-content --id <noteId> | --path <path>
 *  - set-content (--id <noteId> | --path <path>) --text <string>
 *  - append-note (--id <noteId> | --path <path>) --text <string>
 *  - create-log-entry [--root <noteId>] --title <str> --body <str>
 *  - delete-note (--id <noteId> | --path <path>) --force
 *  - search-notes --query <str> [--limit 20]
 *  - list-children --id <noteId> | --path <path>
 *  - rename-note (--id <noteId> | --path <path>) --title <str>
 *  - move-note (--id <noteId> | --path <path>) (--to <noteId> | --to-path <path>)
 *  - resolve-path --path <path>
 *  - create-folder (--parent <id> | --parent-path <path>) --title <str>
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
  const id = await resolveIdOrPath(args, "get-note");
  const out = await etapi(`/etapi/notes/${encodeURIComponent(id)}`);
  jsonOut(out);
}

async function cmdGetContent(args) {
  const id = await resolveIdOrPath(args, "get-content");
  const res = await etapi(`/etapi/notes/${encodeURIComponent(id)}/content`);
  jsonOut({ ok: true, httpStatus: res.httpStatus, path: res.path, content: res.rawText || "" });
}

async function cmdSetContent(args) {
  const id = await resolveIdOrPath(args, "set-content");
  const text = args.text;
  if (!text || text === true) die("set-content requires --text <string>");
  const out = await etapi(`/etapi/notes/${encodeURIComponent(id)}/content`, {
    method: "PUT",
    headers: { "Content-Type": "text/plain; charset=utf-8" },
    body: String(text)
  });
  jsonOut({ ok: true, httpStatus: out.httpStatus, path: out.path });
}

async function cmdAppendNote(args) {
  const id = await resolveIdOrPath(args, "append-note");
  const text = args.text;
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

// ── Path Resolution Helpers ──────────────────────────────────────────

/**
 * Walk the note tree segment by segment to resolve a path string to a noteId.
 * Paths starting with "/" resolve from Trilium root ("root").
 * Other paths resolve from the OpenClaw root note.
 * Matching is case-insensitive.
 */
async function resolvePath(pathStr) {
  const segments = pathStr.split("/").filter(Boolean);
  if (segments.length === 0) die("resolve-path: empty path");

  let currentId;
  if (pathStr.startsWith("/")) {
    currentId = "root";
  } else {
    const store = readStore();
    currentId = store.openclawRootNoteId;
    if (!currentId) die("resolve-path: no OpenClaw root set (run ensure-openclaw-root first)");
  }

  for (const segment of segments) {
    const parentResp = await etapi(`/etapi/notes/${encodeURIComponent(currentId)}`);
    const childIds = parentResp.data?.childNoteIds;
    if (!childIds || childIds.length === 0) {
      die(`resolve-path: "${segment}" not found — "${parentResp.data?.title || currentId}" has no children`);
    }

    let found = null;
    for (const cid of childIds) {
      const childResp = await etapi(`/etapi/notes/${encodeURIComponent(cid)}`);
      if (childResp.data?.title?.toLowerCase() === segment.toLowerCase()) {
        found = cid;
        break;
      }
    }
    if (!found) {
      die(`resolve-path: "${segment}" not found under "${parentResp.data?.title || currentId}"`);
    }
    currentId = found;
  }

  return currentId;
}

/**
 * Return a noteId from --id or --path.
 * If --id is present, return it directly.
 * If --path is present, resolve it via resolvePath().
 * If neither, die with a usage message.
 */
async function resolveIdOrPath(args, label = "command") {
  if (args.id) return args.id;
  if (args.path) return resolvePath(args.path);
  die(`${label} requires --id <noteId> or --path <path>`);
}

// ── File Manager Commands ───────────────────────────────────────────

async function cmdSearchNotes(args) {
  const query = args.query;
  if (!query || query === true) die("search-notes requires --query <string>");
  const limit = args.limit || "20";
  const resp = await etapi(`/etapi/notes?search=${encodeURIComponent(query)}&limit=${encodeURIComponent(limit)}`);
  const results = resp.data?.results || resp.data || [];
  const notes = (Array.isArray(results) ? results : []).map(n => ({
    noteId: n.noteId, title: n.title, type: n.type,
    hasChildren: (n.childNoteIds?.length || 0) > 0
  }));
  jsonOut({ ok: true, count: notes.length, notes });
}

async function cmdListChildren(args) {
  const id = await resolveIdOrPath(args, "list-children");
  const parentResp = await etapi(`/etapi/notes/${encodeURIComponent(id)}`);
  const childIds = parentResp.data?.childNoteIds || [];
  const children = [];
  for (const cid of childIds) {
    const childResp = await etapi(`/etapi/notes/${encodeURIComponent(cid)}`);
    const d = childResp.data || {};
    children.push({
      noteId: d.noteId || cid, title: d.title, type: d.type,
      hasChildren: (d.childNoteIds?.length || 0) > 0
    });
  }
  jsonOut({
    ok: true, parentNoteId: id,
    parentTitle: parentResp.data?.title || null,
    count: children.length, children
  });
}

async function cmdRenameNote(args) {
  const id = await resolveIdOrPath(args, "rename-note");
  const title = args.title;
  if (!title || title === true) die("rename-note requires --title <string>");
  await etapi(`/etapi/notes/${encodeURIComponent(id)}`, {
    method: "PATCH", json: { title }
  });
  jsonOut({ ok: true, noteId: id, newTitle: title });
}

async function cmdMoveNote(args) {
  const id = await resolveIdOrPath(args, "move-note");
  // Resolve destination
  let destId;
  if (args.to) { destId = args.to; }
  else if (args["to-path"]) { destId = await resolvePath(args["to-path"]); }
  else { die("move-note requires --to <noteId> or --to-path <path>"); }

  // Get the note to find its current branch
  const noteResp = await etapi(`/etapi/notes/${encodeURIComponent(id)}`);
  const branchIds = noteResp.data?.parentBranchIds;
  if (!branchIds || branchIds.length === 0) die("move-note: note has no parent branches");
  const oldBranchId = branchIds[0];

  // Create new branch at destination
  const newBranch = await etapi("/etapi/branches", {
    method: "POST", json: { noteId: id, parentNoteId: destId }
  });
  const newBranchId = newBranch.data?.branchId;

  // Delete old branch
  await etapi(`/etapi/branches/${encodeURIComponent(oldBranchId)}`, { method: "DELETE" });

  jsonOut({ ok: true, noteId: id, newParentId: destId, branchId: newBranchId || oldBranchId });
}

async function cmdResolvePath(args) {
  const p = args.path;
  if (!p || p === true) die("resolve-path requires --path <string>");
  const noteId = await resolvePath(p);
  jsonOut({ ok: true, path: p, noteId });
}

async function cmdCreateFolder(args) {
  let parentId;
  if (args.parent) { parentId = args.parent; }
  else if (args["parent-path"]) { parentId = await resolvePath(args["parent-path"]); }
  else {
    const store = readStore();
    parentId = store.openclawRootNoteId;
    if (!parentId) die("create-folder requires --parent <id> or --parent-path <path>");
  }

  const title = args.title;
  if (!title || title === true) die("create-folder requires --title <string>");

  const out = await etapi("/etapi/create-note", {
    method: "POST",
    json: { parentNoteId: parentId, title, type: "text", content: "" }
  });
  const noteId = extractNoteIdFromCreate(out);
  if (!noteId) {
    jsonOut({ ok: false, message: "Could not extract noteId from create-note response" });
    process.exit(1);
  }
  jsonOut({ ok: true, noteId, parentNoteId: parentId, title });
}

// ── Original Commands ───────────────────────────────────────────────

async function cmdDeleteNote(args) {
  const id = await resolveIdOrPath(args, "delete-note");
  const force = args.force === true || args.force === "true";
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
        "trilium-etapi.mjs get-note (--id <noteId> | --path <path>)",
        "trilium-etapi.mjs get-content (--id <noteId> | --path <path>)",
        "trilium-etapi.mjs set-content (--id <noteId> | --path <path>) --text \"...\"",
        "trilium-etapi.mjs append-note (--id <noteId> | --path <path>) --text \"...\"",
        "trilium-etapi.mjs create-log-entry [--root <noteId>] --title \"...\" --body \"...\"",
        "trilium-etapi.mjs delete-note (--id <noteId> | --path <path>) --force",
        "trilium-etapi.mjs search-notes --query \"...\" [--limit 20]",
        "trilium-etapi.mjs list-children (--id <noteId> | --path <path>)",
        "trilium-etapi.mjs rename-note (--id <noteId> | --path <path>) --title \"...\"",
        "trilium-etapi.mjs move-note (--id <noteId> | --path <path>) (--to <noteId> | --to-path <path>)",
        "trilium-etapi.mjs resolve-path --path \"...\"",
        "trilium-etapi.mjs create-folder (--parent <id> | --parent-path <path>) --title \"...\""
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
    case "search-notes": return cmdSearchNotes(args);
    case "list-children": return cmdListChildren(args);
    case "rename-note": return cmdRenameNote(args);
    case "move-note": return cmdMoveNote(args);
    case "resolve-path": return cmdResolvePath(args);
    case "create-folder": return cmdCreateFolder(args);
    default: die(`Unknown command: ${cmd}`);
  }
}

main().catch(err => {
  jsonOut({ ok: false, message: err?.message || String(err) });
  process.exit(1);
});
