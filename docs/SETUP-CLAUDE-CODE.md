# Gemma 4 E4B — Claude Code Configuration

## What This Does

Adds Gemma 4 E4B as an MCP tool inside Claude Code (the CLI). When configured,
you can ask Claude to delegate tasks to Gemma 4 — code generation, review,
summarization, and analysis — all running locally on your machine.

## Prerequisites

1. Ollama running with Gemma 4 E4B (run `./scripts/start.sh` first)
2. MCP server dependencies installed (run `./scripts/install-mcp.sh`)
3. Claude Code installed (`npm install -g @anthropic-ai/claude-code`)

## Option A: Project-Level Config (Recommended)

This project already includes a `.mcp.json` at the root. When you `cd` into
this directory and run `claude`, the MCP server is auto-discovered.

```bash
cd ~/work/innovation/cowork/gemma4-with-vscode
claude
```

The `.mcp.json` file:
```json
{
  "mcpServers": {
    "gemma4-local": {
      "command": "node",
      "args": ["mcp-server/index.js"],
      "env": {
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "GEMMA_MODEL": "gemma4:e4b"
      }
    }
  }
}
```

## Option B: CLI Wizard (`claude mcp add`)

To make Gemma 4 available globally across all projects:

```bash
claude mcp add gemma4-local \
  --command "node" \
  --args "/Users/sborage/work/innovation/cowork/gemma4-with-vscode/mcp-server/index.js" \
  --env OLLAMA_BASE_URL=http://localhost:11434 \
  --env GEMMA_MODEL=gemma4:e4b \
  --scope user
```

This writes to `~/.claude/settings.json` so it's available in every session.

## Option C: Manual Edit (`~/.claude/settings.json`)

Add the following to your `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "gemma4-local": {
      "command": "node",
      "args": ["/Users/sborage/work/innovation/cowork/gemma4-with-vscode/mcp-server/index.js"],
      "env": {
        "OLLAMA_BASE_URL": "http://localhost:11434",
        "GEMMA_MODEL": "gemma4:e4b"
      }
    }
  }
}
```

## Verify It Works

```bash
claude
# Then inside the Claude session:
> Use gemma4_chat to say hello
> Use gemma4_code to write a fibonacci function in Rust
> Use gemma4_analyze to review this for security: [paste code]
```

## Available Tools

Once connected, these tools appear in Claude Code:

| Tool | Purpose | Example |
|------|---------|---------|
| `gemma4_chat` | General chat/brainstorming | "Use gemma4_chat to explain the actor model" |
| `gemma4_code` | Code gen/review/debug | "Use gemma4_code to review this Python file" |
| `gemma4_summarize` | Summarize text/docs | "Use gemma4_summarize on this PR description" |
| `gemma4_analyze` | Architecture/security analysis | "Use gemma4_analyze for security on this code" |

## Troubleshooting

- **"MCP server failed to start"**: Run `node mcp-server/index.js` manually to see errors. Usually means `npm install` wasn't run in `mcp-server/`.
- **"Connection refused"**: Ollama isn't running. Run `./scripts/start.sh`.
- **Tool not showing up**: Restart Claude Code after adding the config. Check `claude mcp list` to verify.
