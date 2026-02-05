# D5 — Tool Registration: trilium_thread_router

This project does not have a standard OpenClaw tool registration file. To register the Trilium thread router as a tool, add the following to your OpenClaw server configuration.

## Tool Definition

Name: trilium_thread_router
Description: Natural-language router for Trilium threads (last/active). Supports: show last/active thread, append text, summarize stub.

### Parameters

- utterance (string, required): User request, e.g. "show me the last discord thread", "append this", "summarize decisions"
- text (string, optional): Text payload for append intent
- source (string, optional): Source selector, default "discord"
- channel (string, optional): Channel scope hint
- guild (string, optional): Guild scope hint

### Implementation

The tool should invoke:

    python3 workflows/router/d4_nl_route.py

With stdin JSON:

    {"utterance": "...", "text": "...", "source": "discord", "channel": "", "guild": ""}

The router returns JSON with:
- ok: boolean
- intent: "show_thread" | "append" | "summarize" | "unknown"
- threadKey: string
- noteId: string
- content or summary_stub: depending on intent

### TypeScript Snippet (for api.registerTool)

api.registerTool({
  name: 'trilium_thread_router',
  description: 'Natural-language router for Trilium threads. Supports: show, append, summarize.',
  parameters: {
    type: 'object',
    properties: {
      utterance: { type: 'string', description: 'User request' },
      text: { type: 'string', description: 'Optional text for append' },
      source: { type: 'string', default: 'discord' }
    },
    required: ['utterance']
  },
  async execute(_id, params) {
    const { execFile } = await import('node:child_process');
    const { promisify } = await import('node:util');
    const execFileAsync = promisify(execFile);
    const input = JSON.stringify(params);
    const { stdout } = await execFileAsync('python3', ['workflows/router/d4_nl_route.py'], { input, cwd: process.cwd(), env: process.env });
    return { content: [{ type: 'text', text: stdout.trim() }] };
  }
});

### Usage Examples

1) Show last thread:
   Tool call: trilium_thread_router({ utterance: "show me the last discord thread" })

2) Append to thread:
   Tool call: trilium_thread_router({ utterance: "append this", text: "New log entry" })

3) Summarize:
   Tool call: trilium_thread_router({ utterance: "summarize decisions from that convo" })
