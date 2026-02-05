# D2 — Discord Hook Adapter (HTTP → D1 ingest → Trilium)

Purpose:
- Provide a lightweight local HTTP endpoint that your Discord bot (or any forwarder) can POST to.
- The server normalizes a few common Discord payload shapes into the D1 ingest format.
- It then calls D1 (stdin JSON) which handles:
  - thread key computation
  - structured intake start (C4)
  - append follow-ups (C4)
  - persistent thread state (C2)

Server:
- workflows/ingest/d2_discord_webhook_server.py

Env required (same as D1):
- TRILIUM_BASE_URL
- TRILIUM_API_TOKEN

Optional env:
- D2_HOST (default 127.0.0.1)
- D2_PORT (default 8787)

Start server:
- python3 workflows/ingest/d2_discord_webhook_server.py

POST endpoint:
- http://127.0.0.1:8787/discord

Payload accepted (examples):
1) D1-native:
- { "guild_id":"...", "channel_id":"...", "message_id":"...", "root_message_id":"...", "author":"...", "content":"...", "jump_url":"..." }

2) discord.js-like:
- { "id":"...", "channelId":"...", "guildId":"...", "content":"...", "author":{"username":"..."}, "url":"...", "reference":{"messageId":"..."} }

Logging:
- Received normalized events are appended to tmp/discord_events.jsonl (gitignored).
