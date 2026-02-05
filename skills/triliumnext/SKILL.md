---
name: triliumnext
description: TriliumNext knowledge base integration for OpenClaw
metadata:
  openclaw:
    emoji: "🧠"
requires:
  bins:
    - python3
    - curl
  env:
    - TRILIUM_BASE_URL
    - TRILIUM_API_TOKEN
primaryEnv: TRILIUM_API_TOKEN
---

# TriliumNext Skill

Integrates TriliumNext knowledge base with OpenClaw, enabling note creation, retrieval, updating, and search capabilities.

## Commands

### ping
Test connectivity to the TriliumNext server.

```bash
triliumnext.py ping
```

### note create
Create a new note in TriliumNext.

```bash
triliumnext.py note create --title "Note Title" --content "Note content" [--parent-id <id>]
```

### note get
Retrieve a note by ID.

```bash
triliumnext.py note get <note-id>
```

### note update
Update an existing note.

```bash
triliumnext.py note update <note-id> [--title "New Title"] [--content "New content"]
```

### note search
Search for notes.

```bash
triliumnext.py note search <query>
```

## Options

- `--json` - Output results as JSON (for programmatic use)

## Environment Variables

- `TRILIUM_BASE_URL` - Base URL of the TriliumNext server (e.g., `http://localhost:8080`)
- `TRILIUM_API_TOKEN` - ETAPI authentication token
