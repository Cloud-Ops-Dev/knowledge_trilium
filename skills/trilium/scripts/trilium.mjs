#!/usr/bin/env node
/**
 * OpenClaw Skill Proxy — TriliumNext
 *
 * Delegates all commands to:
 *   <repoRoot>/tools/trilium-etapi.mjs
 */

import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Resolve repo root: skills/trilium/scripts -> repo root
const repoRoot = path.resolve(__dirname, "..", "..", "..");
const wrapperPath = path.join(repoRoot, "tools", "trilium-etapi.mjs");

const args = process.argv.slice(2);

const res = spawnSync("node", [wrapperPath, ...args], {
  stdio: "inherit",
  env: process.env
});

process.exit(res.status ?? 1);
