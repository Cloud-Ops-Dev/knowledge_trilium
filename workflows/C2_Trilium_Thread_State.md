# C2 — Trilium Thread State (Persistent noteId)

Goal:
- Persist a Trilium noteId per logical "thread" key so OpenClaw can resume a note across turns.

State storage:
- workflows/state/threads.json (gitignored)

Commands:
- Start a thread (creates Trilium note if missing; otherwise reuses stored noteId):
  - workflows/c2_trilium_thread.sh start --thread THREAD_KEY --title "..." --body "..."

- Append to an existing thread:
  - workflows/c2_trilium_thread.sh append --thread THREAD_KEY --text "..."

- Read content for a thread:
  - workflows/c2_trilium_thread.sh get --thread THREAD_KEY

- Close a thread (removes mapping; optional delete):
  - workflows/c2_trilium_thread.sh close --thread THREAD_KEY --delete true

Recommended thread keys:
- Use stable identifiers such as:
  - "discord:<channelId>:<messageId>"
  - "web:<formId>"
  - "local:<project>:<topic>"
