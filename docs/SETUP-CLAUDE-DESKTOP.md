# Gemma 4 E4B — Claude Desktop Configuration (Chat, Cowork & Code)

## What This Does

Adds Gemma 4 E4B as an MCP server in Claude Desktop. Once configured,
Gemma 4 tools are available across **all three modes**: Chat, Cowork, and Code.
Claude can delegate local AI tasks to Gemma 4 running on your machine.

## Prerequisites

1. Ollama running with Gemma 4 E4B (run `./scripts/start.sh` first)
2. MCP server dependencies installed (run `./scripts/install-mcp.sh`)
3. Claude Desktop app installed

## Step-by-Step Configuration

### Step 1: Open the Config File

**Via Claude Desktop UI:**
1. Open Claude Desktop
2. Go to **Settings** (gear icon) → **Developer** → **Edit Config**
3. This opens `claude_desktop_config.json` in your default editor

**Via Terminal:**
```bash
# macOS
open ~/Library/Application\ Support/Claude/claude_desktop_config.json

# If the file doesn't exist yet, create it:
mkdir -p ~/Library/Application\ Support/Claude
echo '{}' > ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### Step 2: Add the MCP Server

Add (or merge) this into your `claude_desktop_config.json`:

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

> **Important:** If you already have other MCP servers configured, merge the
> `gemma4-local` entry into your existing `mcpServers` object. Don't replace
> the whole file.

### Step 3: Restart Claude Desktop

Quit Claude Desktop completely (Cmd+Q) and reopen it. The MCP server connects
on startup.

### Step 4: Verify

In any Claude Desktop conversation, you should see the MCP tools icon (hammer)
in the input area. Click it to confirm `gemma4_chat`, `gemma4_code`,
`gemma4_summarize`, and `gemma4_analyze` appear.

## How It Works in Each Mode

### Chat Mode
Ask Claude to use Gemma 4 for a second opinion or local processing:
```
"Use gemma4_chat to explain how Rust's borrow checker works"
"Ask gemma4_code to generate a Python decorator for retry logic"
"Use gemma4_summarize on this text: [paste text]"
```

### Cowork Mode
In Cowork, Claude can automatically delegate to Gemma 4 as part of
multi-step workflows. For example:
```
"Review my codebase for security issues — use gemma4_analyze for a second opinion"
"Summarize each file in this folder using gemma4_summarize"
```

Cowork mode treats MCP tools the same as Chat mode — the same `claude_desktop_config.json`
powers both.

### Code Mode
In Code mode within Claude Desktop, the MCP server works identically.
Claude can call Gemma 4 tools while helping you with coding tasks:
```
"Debug this function and cross-check with gemma4_code"
"Use gemma4_analyze to check this for performance issues"
```

## Example Config (with other MCP servers)

If you already use other MCP servers, your config might look like this:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/sborage/Documents"]
    },
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

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| No MCP tools icon | Restart Claude Desktop after editing config |
| "Server disconnected" | Check Ollama is running: `curl http://localhost:11434/api/tags` |
| Tools appear but fail | Run `node mcp-server/index.js` manually to check for errors |
| Slow first response | Normal — model loads into memory on first call (~3-5s) |
| "ENOENT" error | Verify the absolute path in `args` is correct |
