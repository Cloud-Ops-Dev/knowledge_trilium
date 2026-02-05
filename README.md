# knowledge_trilium

**TriliumNext Knowledge Management for OpenClaw**

A project by [Novique.ai](https://github.com/Cloud-Ops-Dev/novique.ai) — bringing structured knowledge capture and retrieval to the OpenClaw environment through TriliumNext's ETAPI.

---

## Overview

`knowledge_trilium` provides a complete integration stack connecting [OpenClaw](https://github.com/Cloud-Ops-Dev) with [TriliumNext](https://github.com/TriliumNext/Notes), a self-hosted hierarchical note-taking application. It enables:

- **Automated ingestion** of Discord messages into structured Trilium notes
- **Persistent thread state** across conversation turns with pointer-based resolution
- **Natural-language routing** for show, append, and summarize operations
- **OpenClaw skill interface** for seamless tool integration

---

## Architecture

```
                        +-----------------------+
                        |    Discord / HTTP      |
                        +-----------+-----------+
                                    |
                    +---------------v----------------+
                    |  D1: Discord Ingest Adapter     |
                    |  D2: Webhook Server (port 8787) |
                    +---------------+----------------+
                                    |
                    +---------------v----------------+
                    |  C4: Structured Intake Template  |
                    |  C2: Thread State Manager        |
                    +---------------+----------------+
                                    |
                    +---------------v----------------+
                    |  ETAPI Wrapper (trilium-etapi)   |
                    +---------------+----------------+
                                    |
                    +---------------v----------------+
                    |  TriliumNext (port 3011)         |
                    +---------------------------------+

  Parallel path:

  User utterance ──> D4: NL Router ──> C2 + ETAPI ──> Response
```

---

## Components

| Component | Layer | Description |
|-----------|-------|-------------|
| `tools/trilium-etapi.mjs` | Core | Node.js ETAPI wrapper — JSON-only CLI for all Trilium operations |
| `workflows/c2_trilium_thread.sh` | State | Thread state manager — persistent key-to-noteId mapping with pointer resolution |
| `workflows/c4_trilium_intake.sh` | Workflow | Structured intake helper — template-based note creation |
| `workflows/ingest/d1_discord_ingest.py` | Ingest | Discord JSON adapter — stdin pipeline for message capture |
| `workflows/ingest/d2_discord_webhook_server.py` | Ingest | HTTP endpoint — accepts Discord bot payloads on port 8787 |
| `workflows/router/d4_nl_route.py` | Router | Natural-language intent router — show, append, summarize |
| `skills/trilium/` | Skill | OpenClaw skill proxy — exposes ETAPI commands as a registered tool |
| `infra/trilium/` | Infra | Docker Compose setup for TriliumNext on port 3011 |

---

## Quick Start

### 1. Start TriliumNext

```bash
cd infra/trilium
docker compose up -d
```

### 2. Obtain an ETAPI Token

Open `http://127.0.0.1:3011` in a browser, then navigate to **Menu > Options > ETAPI** and generate a token. See [`infra/trilium/docs/etapi-token.md`](infra/trilium/docs/etapi-token.md) for detailed instructions.

### 3. Configure Environment

```bash
export TRILIUM_BASE_URL="http://127.0.0.1:3011"
export TRILIUM_API_TOKEN="your-token-here"
```

### 4. Verify Connection

```bash
node tools/trilium-etapi.mjs app-info
```

### 5. Bootstrap the OpenClaw Root Note

```bash
node tools/trilium-etapi.mjs ensure-openclaw-root
```

### 6. Run Tests

```bash
./tools/trilium-etapi.smoketest.sh   # Basic connectivity and CRUD
./tools/trilium-etapi.b5test.sh      # Full contract validation
```

---

## Usage

### ETAPI Wrapper

The core CLI tool for all Trilium operations. Every command outputs JSON.

```bash
# Check connection
node tools/trilium-etapi.mjs app-info

# Create a note
node tools/trilium-etapi.mjs create-note --parent root --title "My Note"

# Read content
node tools/trilium-etapi.mjs get-content --id <noteId>

# Append text
node tools/trilium-etapi.mjs append-note --id <noteId> --text "Additional content"

# Create a timestamped log entry
node tools/trilium-etapi.mjs create-log-entry --title "Event" --body "Details here"

# Delete a note
node tools/trilium-etapi.mjs delete-note --id <noteId> --force
```

<details>
<summary><strong>All ETAPI Commands</strong></summary>

| Command | Description |
|---------|-------------|
| `app-info` | Test connectivity |
| `print-config` | Show current configuration |
| `ensure-openclaw-root` | Create or reuse the OpenClaw root note |
| `create-note` | Create a child note (`--parent`, `--title`, `--type`) |
| `get-note` | Fetch note metadata (`--id`) |
| `get-content` | Read note content (`--id`) |
| `set-content` | Replace note content (`--id`, `--text`) |
| `append-note` | Append to note content (`--id`, `--text`) |
| `create-log-entry` | Create timestamped entry (`--title`, `--body`) |
| `delete-note` | Delete a note (`--id`, `--force`) |

</details>

---

### Thread State Management

Maintain persistent threads across conversation turns with automatic pointer tracking.

```bash
# Start a new thread
./workflows/c2_trilium_thread.sh start \
  --thread "discord:789:123:456" \
  --title "Intake: Security Alert" \
  --body "Initial report details"

# Append to an existing thread
./workflows/c2_trilium_thread.sh append \
  --thread "discord:789:123:456" \
  --text "Investigation update: resolved"

# Retrieve thread content
./workflows/c2_trilium_thread.sh get --thread "discord:789:123:456"

# Get the most recent thread
./workflows/c2_trilium_thread.sh get-latest --source discord

# Check pointer state
./workflows/c2_trilium_thread.sh status
```

**Thread keys** follow the format `source:context:ids` (e.g., `discord:<guild>:<channel>:<root_msg>`).

**Pointer resolution** follows a preference hierarchy:
1. Active thread (explicitly marked)
2. Channel-specific (`discord:channel:<id>`)
3. Guild-specific (`discord:guild:<id>`)
4. Source-specific (`discord:last`)
5. Global fallback (`global:last`)

---

### Discord Ingestion

#### Stdin Pipeline (D1)

```bash
echo '{
  "channel_id": "123",
  "message_id": "456",
  "guild_id": "789",
  "author": "username",
  "content": "Important message to capture"
}' | python3 workflows/ingest/d1_discord_ingest.py
```

#### HTTP Webhook Server (D2)

```bash
# Start the server
python3 workflows/ingest/d2_discord_webhook_server.py

# POST from a Discord bot or forwarder
curl -X POST http://127.0.0.1:8787/discord \
  -H "Content-Type: application/json" \
  -d '{"id": "456", "channelId": "123", "content": "Hello from Discord"}'
```

The webhook server accepts both D1-native and discord.js-style payloads with automatic normalization.

---

### Natural-Language Routing (D4)

Query and manipulate threads using plain English.

```bash
# Show the last thread
echo '{"utterance": "show me the last discord thread"}' \
  | python3 workflows/router/d4_nl_route.py

# Append to the active thread
echo '{"utterance": "add this to the thread", "text": "New entry"}' \
  | python3 workflows/router/d4_nl_route.py

# Summarize decisions
echo '{"utterance": "summarize decisions from the last conversation"}' \
  | python3 workflows/router/d4_nl_route.py
```

**Supported intents:** `show_thread`, `append`, `summarize`

---

## Structured Intake Template

Every ingested note follows a consistent format:

```markdown
OpenClaw Intake

Thread: discord:789:123:456
Source: discord
Created (UTC): 2026-02-05T12:00:00Z

Summary
- Brief description of the captured content

Context
Channel: 123 | Guild: 789 | Message: 456

Signals / Risks
- None yet

Actions
- [ ] Triage and classify

Links
- (none)

Log
- 2026-02-05T12:00:00Z — Created intake entry.
```

---

## Project Structure

```
knowledge_trilium/
├── infra/trilium/               # TriliumNext Docker setup
│   ├── docker-compose.yml
│   └── docs/etapi-token.md
│
├── tools/                       # Core ETAPI wrapper + tests
│   ├── trilium-etapi.mjs
│   ├── trilium-etapi.smoketest.sh
│   └── trilium-etapi.b5test.sh
│
├── skills/                      # OpenClaw skill definitions
│   ├── trilium/                 #   Node.js skill proxy
│   └── triliumnext/             #   Python skill (planned)
│
└── workflows/
    ├── c2_trilium_thread.sh     # Thread state manager
    ├── c4_trilium_intake.sh     # Structured intake helper
    ├── templates/intake.md      # Note template
    ├── ingest/                  # Discord adapters (D1, D2)
    └── router/                  # NL intent router (D4)
```

---

## Requirements

| Dependency | Version | Purpose |
|------------|---------|---------|
| Node.js | 18+ | ETAPI wrapper |
| Python | 3.10+ | Ingest adapters, NL router |
| jq | any | JSON processing in shell scripts |
| Docker / Podman | any | TriliumNext container |

**Environment variables:**

| Variable | Required | Description |
|----------|----------|-------------|
| `TRILIUM_BASE_URL` | Yes | TriliumNext URL (e.g., `http://127.0.0.1:3011`) |
| `TRILIUM_API_TOKEN` | Yes | ETAPI authentication token |
| `D2_HOST` | No | Webhook server bind address (default: `127.0.0.1`) |
| `D2_PORT` | No | Webhook server port (default: `8787`) |

---

## Port Assignments

| Port | Service | Binding |
|------|---------|---------|
| 3011 | TriliumNext | `127.0.0.1` only |
| 8787 | Discord Webhook Server | `127.0.0.1` only |

---

## License

MIT
