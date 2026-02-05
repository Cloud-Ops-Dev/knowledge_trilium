# D4 — Natural-Language Thread Routing (Active/Last)

Purpose:
- Provide a single JSON-in/JSON-out router that converts natural language into actions:
  - show last/active thread note content
  - append text to last/active thread
  - summarize decisions/next steps (router produces a stub; OpenClaw can do full LLM pass)

File:
- workflows/router/d4_nl_route.py

Input (stdin JSON):
- utterance: required
- text: optional (required for append intent)
- source: optional (default "discord")

Examples:
1) Show last Discord thread:
- echo '{"utterance":"show me the last discord thread"}' | workflows/router/d4_nl_route.py

2) Append:
- echo '{"utterance":"append this to that thread","text":"New note line"}' | workflows/router/d4_nl_route.py

3) Summarize:
- echo '{"utterance":"summarize decisions and next steps from the last convo"}' | workflows/router/d4_nl_route.py

Thread resolution:
- Uses C2 get-latest with prefer-active=true (default)
- Sets active thread automatically on successful routing

Dependencies:
- workflows/c2_trilium_thread.sh (D3)
- skills/trilium/scripts/trilium.mjs (B6)
- workflows/state/threads.json mapping must include noteId for each threadKey
