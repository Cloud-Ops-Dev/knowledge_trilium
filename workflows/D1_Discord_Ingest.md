# D1 — Discord Ingest → Trilium

Goal:
- Turn Discord messages into structured Trilium intake notes with persistent thread state.

What this adds:
- workflows/ingest/d1_discord_ingest.py
  - Reads a Discord-like JSON payload from stdin
  - Computes a stable thread key:
    discord:<guild_id>:<channel_id>:<root_message_id>
  - If thread is new:
    - Creates a structured intake note via workflows/c4_trilium_intake.sh start
  - If thread exists:
    - Appends new messages to the existing note via workflows/c4_trilium_intake.sh append

State:
- workflows/state/threads.json (from C2) stores threadKey -> noteId mapping.

Required env:
- TRILIUM_BASE_URL
- TRILIUM_API_TOKEN

Expected input JSON fields (minimum):
- channel_id
- message_id
- content
Optional:
- guild_id
- author
- jump_url
- root_message_id (highly recommended for replies)

Usage pattern:
- Your Discord bot (or OpenClaw ingress) should pass a JSON payload to stdin:
  echo '<json>' | python3 workflows/ingest/d1_discord_ingest.py

Recommendation:
- For replies, set root_message_id to the original message you want to treat as the thread root.
- If you cannot provide that, the script will default root_message_id = message_id, which creates one note per message.
