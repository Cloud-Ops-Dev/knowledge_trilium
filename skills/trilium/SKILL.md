---
name: trilium
description: "Integrate with TriliumNext via ETAPI for note creation, logging, and content management."
metadata:
  openclaw:
    emoji: "🗂️"
    requires:
      bins: ["node"]
      env: ["TRILIUM_BASE_URL", "TRILIUM_API_TOKEN"]
    primaryEnv: "TRILIUM_API_TOKEN"
---

# TriliumNext Skill (OpenClaw)

This skill gives OpenClaw a stable CLI interface to TriliumNext by proxying to the repo wrapper:
- tools/trilium-etapi.mjs

## Requirements

Env vars:
- TRILIUM_BASE_URL (example: http://127.0.0.1:3011)
- TRILIUM_API_TOKEN

Binary:
- node

## Usage

OpenClaw exposes `{baseDir}` as the skill directory path.

Sanity check:
- node {baseDir}/scripts/trilium.mjs print-config
- node {baseDir}/scripts/trilium.mjs app-info

One-time bootstrap (recommended):
- node {baseDir}/scripts/trilium.mjs ensure-openclaw-root

Create a log entry:
- node {baseDir}/scripts/trilium.mjs create-log-entry --title "Daily Intake" --body "Notes go here"

Read / modify content:
- node {baseDir}/scripts/trilium.mjs get-content --id NOTE_ID
- node {baseDir}/scripts/trilium.mjs append-note --id NOTE_ID --text "More text"
- node {baseDir}/scripts/trilium.mjs set-content --id NOTE_ID --text "Full replacement content"

Delete (explicit force required):
- node {baseDir}/scripts/trilium.mjs delete-note --id NOTE_ID --force
