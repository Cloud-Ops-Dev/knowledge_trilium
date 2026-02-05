# knowledge_trillium

## Overview

TriliumNext ETAPI integration for OpenClaw. Provides a complete stack for:
- Capturing Discord messages as structured Trilium notes
- Persistent thread state across conversation turns
- Natural-language routing for show/append/summarize operations
- OpenClaw skill interface for Trilium operations

## Technology Stack

- **Node.js** - ETAPI wrapper (tools/trilium-etapi.mjs)
- **Python 3** - Ingest adapters, NL router
- **Bash** - Thread state manager, workflow scripts
- **jq** - JSON processing in shell scripts
- **TriliumNext** - Note storage backend (ETAPI)

## Requirements

Environment variables (required):
- `TRILIUM_BASE_URL` - e.g., `http://127.0.0.1:3011`
- `TRILIUM_API_TOKEN` - ETAPI token from TriliumNext

Binaries:
- `node` (v18+)
- `python3` (3.10+)
- `jq`
- `curl`

## Project Structure

```
knowledge_trillium/
├── CLAUDE.md                          # This file
├── README.md                          # Public documentation
├── .gitignore
│
├── infra/trilium/
│   ├── docker-compose.yml             # TriliumNext container
│   ├── .env                           # Port/URL config
│   └── docs/etapi-token.md            # Token acquisition guide
│
├── tools/
│   ├── trilium-etapi.mjs              # Core ETAPI wrapper (B5 contract)
│   ├── trilium-etapi.smoketest.sh     # Basic smoke test
│   ├── trilium-etapi.b4test.sh        # Append test
│   └── trilium-etapi.b5test.sh        # Full contract test
│
├── skills/
│   └── trilium/
│       ├── SKILL.md                   # OpenClaw skill definition
│       └── scripts/trilium.mjs        # Skill proxy → tools/
│
├── workflows/
│   ├── state/                         # Runtime state (gitignored)
│   │   ├── threads.json               # Thread key → noteId mapping
│   │   └── last_thread.json           # Pointer state (active/last)
│   │
│   ├── templates/
│   │   └── intake.md                  # Structured intake template
│   │
│   ├── ingest/
│   │   ├── d1_discord_ingest.py       # Discord JSON → Trilium (stdin)
│   │   └── d2_discord_webhook_server.py  # HTTP endpoint for Discord
│   │
│   ├── router/
│   │   └── d4_nl_route.py             # NL intent router
│   │
│   ├── c1_trilium_intake_demo.sh      # Basic intake demo
│   ├── c2_trilium_thread.sh           # Thread state manager
│   ├── c4_trilium_intake.sh           # Structured intake helper
│   │
│   └── *.md                           # Workflow documentation
│
└── tmp/                               # Test artifacts (gitignored)
```

## Quick Start

```bash
# 1. Set environment
export TRILIUM_BASE_URL="http://127.0.0.1:3011"
export TRILIUM_API_TOKEN="your-token-here"

# 2. Verify ETAPI connection
node tools/trilium-etapi.mjs app-info

# 3. Bootstrap OpenClaw root note
node tools/trilium-etapi.mjs ensure-openclaw-root

# 4. Run smoke tests
./tools/trilium-etapi.smoketest.sh
./tools/trilium-etapi.b5test.sh
```

## Core Components

### ETAPI Wrapper (tools/trilium-etapi.mjs)

Commands:
- `app-info` - Check connection
- `print-config` - Show current config
- `ensure-openclaw-root` - Create/reuse OpenClaw root note
- `create-note --parent ID --title "..." [--type text]`
- `get-note --id ID`
- `get-content --id ID`
- `set-content --id ID --text "..."`
- `append-note --id ID --text "..."`
- `create-log-entry --title "..." --body "..."`
- `delete-note --id ID --force`

### Thread State Manager (workflows/c2_trilium_thread.sh)

Commands:
- `start --thread KEY --title "..." --body "..."` - Create thread note
- `append --thread KEY --text "..."` - Append to thread
- `get --thread KEY` - Get thread content
- `close --thread KEY [--delete true]` - Close thread
- `get-latest [--source discord]` - Get most recent thread key
- `set-active --thread KEY` - Set active thread
- `clear-active` - Clear active pointer
- `status` - Show pointer state

### Discord Ingest (workflows/ingest/)

**d1_discord_ingest.py** - Stdin JSON adapter:
```bash
echo '{"channel_id":"123","message_id":"456","content":"Hello"}' | python3 workflows/ingest/d1_discord_ingest.py
```

**d2_discord_webhook_server.py** - HTTP endpoint:
```bash
python3 workflows/ingest/d2_discord_webhook_server.py
# POST http://127.0.0.1:8787/discord
```

### NL Router (workflows/router/d4_nl_route.py)

Intents:
- **show_thread**: "show me the last discord thread"
- **append**: "append this to that thread" + text field
- **summarize**: "summarize decisions from the last convo"

```bash
echo '{"utterance":"show me the last discord thread"}' | python3 workflows/router/d4_nl_route.py
```

## State Files (gitignored)

- `workflows/state/threads.json` - Maps thread keys to Trilium noteIds
- `workflows/state/last_thread.json` - Pointer state for get-latest resolution
- `tools/.openclaw-trilium.json` - OpenClaw root noteId

## TriliumNext ETAPI Notes

- Create note: `POST /etapi/create-note` (not `/etapi/notes`)
- Get/delete note: `GET/DELETE /etapi/notes/{id}`
- Get content: `GET /etapi/notes/{id}/content` (returns raw text)
- Set content: `PUT /etapi/notes/{id}/content` (Content-Type: text/plain)

## Important Notes

- Token is stored in environment, never committed
- State files in workflows/state/ are gitignored
- TriliumNext must be running for any operations
- Thread keys follow format: `discord:{guild}:{channel}:{root_msg}`

---

**Last Updated:** February 5, 2026
