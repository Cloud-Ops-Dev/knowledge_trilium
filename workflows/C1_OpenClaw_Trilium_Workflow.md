# C1 — OpenClaw ↔ TriliumNext Workflow (Intake → Append → Read)

Goal:
- Create a Trilium log entry for an intake message
- Capture returned noteId
- Append follow-ups to the same note
- Read note content back for context injection

Requirements:
- TRILIUM_BASE_URL (example: http://127.0.0.1:3011)
- TRILIUM_API_TOKEN
- node installed

Skill entrypoint:
- skills/trilium/scripts/trilium.mjs

Core commands:
- Ensure OpenClaw root note exists:
  - node skills/trilium/scripts/trilium.mjs ensure-openclaw-root

- Create intake log entry (returns JSON containing noteId):
  - node skills/trilium/scripts/trilium.mjs create-log-entry --title "Intake: <title>" --body "<body>"

- Append follow-up (requires noteId):
  - node skills/trilium/scripts/trilium.mjs append-note --id <noteId> --text "<follow up>"

- Read content for context:
  - node skills/trilium/scripts/trilium.mjs get-content --id <noteId>

Recommended OpenClaw pattern:
1) On first intake message:
   - ensure-openclaw-root
   - create-log-entry
   - store noteId in your session state (task memory / scratch / db)

2) On subsequent turns:
   - append-note (same noteId)
   - optionally get-content and feed into planning prompts

Notes:
- No search is used (your TriliumNext ETAPI doesn't expose /etapi/search).
- Prefer create-log-entry for auditability (each intake becomes its own note).
