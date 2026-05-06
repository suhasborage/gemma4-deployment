# Gemma 4 E4B — Local AI for Claude Code, Claude Desktop & VS Code

Run Google's **Gemma 4 E4B** (9.6GB, 128K context, multimodal) locally via Docker/Ollama
and integrate it with your full AI development workflow.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Your Mac (Apple Silicon)                    │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌────────────┐  ┌───────────────────┐  ┌─────────────────┐  │
│  │ Claude Code│  │  Claude Desktop   │  │    VS Code +    │  │
│  │   (CLI)    │  │ (Chat/Cowork/Code)│  │  Continue Ext   │  │
│  └─────┬──────┘  └────────┬──────────┘  └───────┬─────────┘  │
│        │                   │                      │            │
│        └────────┬──────────┘                      │            │
│                 │ (MCP Protocol - stdio)           │ (HTTP)     │
│                 ▼                                  ▼            │
│  ┌──────────────────────────┐   ┌───────────────────────────┐ │
│  │  MCP Server (Node.js)    │   │  Ollama API               │ │
│  │  gemma4_chat             │──▶│  http://localhost:11434    │ │
│  │  gemma4_code             │   │  /v1/chat/completions     │ │
│  │  gemma4_summarize        │   └────────────┬──────────────┘ │
│  │  gemma4_analyze          │                │                │
│  └──────────────────────────┘   ┌────────────▼──────────────┐ │
│                                  │  Docker: Ollama            │ │
│                                  │  Model: gemma4:e4b         │ │
│                                  │  9.6GB · 128K ctx · Q4_K_M │ │
│                                  └───────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Gemma 4 E4B Model Variants

| Ollama Tag | Size | Quantization | Best For |
|-----------|------|--------------|----------|
| `gemma4:e4b` | 9.6GB | Q4_K_M (default) | General use, best speed/quality balance |
| `gemma4:e4b-it-q8_0` | 12GB | Q8_0 | Higher quality output |
| `gemma4:e4b-it-bf16` | 16GB | BFloat16 (full) | Maximum quality, needs 16GB+ RAM |

## Prerequisites

- macOS with Apple Silicon (M1/M2/M3/M4), 16GB+ RAM recommended
- Docker Desktop installed and running
- Node.js 18+ (for MCP server)
- Python 3.10+ (for example scripts)

---

## Quick Start (5 Minutes)

```bash
cd ~/work/innovation/cowork/gemma4-with-vscode

# 1. Make scripts executable
chmod +x scripts/*.sh

# 2. Start Ollama + pull Gemma 4 E4B (~9.6GB download on first run)
./scripts/start.sh

# 3. Install MCP server dependencies
./scripts/install-mcp.sh

# 4. Verify everything works
./scripts/test-api.sh
```

---

## Configuration Guide

### 1. Claude Code (CLI)

**Full guide:** [docs/SETUP-CLAUDE-CODE.md](docs/SETUP-CLAUDE-CODE.md)

**Quickest method** — project-level `.mcp.json` (auto-discovered when you `cd` into this folder):

```bash
# Rename the provided template
mv mcp.json .mcp.json

# Now just run claude from this directory
claude
> Use gemma4_chat to explain the visitor pattern
```

**Global setup** — available in every Claude Code session:

```bash
claude mcp add gemma4-local \
  --command "node" \
  --args "$PWD/mcp-server/index.js" \
  --env OLLAMA_BASE_URL=http://localhost:11434 \
  --env GEMMA_MODEL=gemma4:e4b \
  --scope user
```

---

### 2. Claude Desktop (Chat, Cowork & Code)

**Full guide:** [docs/SETUP-CLAUDE-DESKTOP.md](docs/SETUP-CLAUDE-DESKTOP.md)

**Step 1:** Open config — Settings → Developer → Edit Config

**Step 2:** Add this to `~/Library/Application Support/Claude/claude_desktop_config.json`:

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

**Step 3:** Restart Claude Desktop (Cmd+Q, reopen)

Works identically in Chat mode, Cowork mode, and Code mode — all share the same
MCP server config.

---

### 3. VS Code (Continue Extension)

**Full guide:** [docs/SETUP-VSCODE.md](docs/SETUP-VSCODE.md)

**Step 1:** Install Continue extension
```bash
code --install-extension continue.continue
```

**Step 2:** Copy config
```bash
cp -r .continue ~/.continue
```

**Step 3:** Open VS Code, press **Cmd+L**, and chat with Gemma 4

**Key features:**
- **Cmd+L** — Chat sidebar
- **Cmd+I** — Inline code edit
- **Tab** — Autocomplete
- `/review`, `/explain`, `/refactor`, `/tests` — Custom commands

---

## Sample Use Cases

```bash
pip install requests

# Code generation (LRU cache, FastAPI endpoint, bash script)
python examples/01-code-generation.py

# Security code review
python examples/02-code-review.py

# Multi-style summarization
python examples/03-summarization.py

# Interactive streaming chat
python examples/04-chat-streaming.py

# Non-interactive demo
python examples/04-chat-streaming.py --demo
```

---

## Performance Notes

**Docker on Apple Silicon** (CPU mode):
- ~10-20 tokens/sec generation
- ~3-5s cold start on first request
- 9.6GB model RAM usage

**Native Ollama** (Metal GPU — faster, optional):
```bash
brew install ollama
ollama serve &
ollama pull gemma4:e4b
```
- ~30-50 tokens/sec generation
- Same API endpoint (`localhost:11434`), all configs work unchanged

---

## File Structure

```
gemma4-with-vscode/
├── docker-compose.yml              # Ollama container
├── mcp.json                        # Rename to .mcp.json for Claude Code
├── scripts/
│   ├── start.sh                   # Start Ollama + pull model
│   ├── stop.sh                    # Stop containers
│   ├── test-api.sh               # Verify API
│   └── install-mcp.sh            # Install MCP dependencies
├── mcp-server/
│   ├── package.json
│   └── index.js                   # MCP server (4 tools)
├── .continue/
│   └── config.json                # Continue extension config
├── vscode-settings/
│   ├── settings.json
│   └── extensions.json
├── examples/
│   ├── 01-code-generation.py
│   ├── 02-code-review.py
│   ├── 03-summarization.py
│   └── 04-chat-streaming.py
├── docs/
│   ├── SETUP-CLAUDE-CODE.md       # Detailed Claude Code guide
│   ├── SETUP-CLAUDE-DESKTOP.md    # Detailed Desktop guide (all modes)
│   └── SETUP-VSCODE.md           # Detailed VS Code guide
├── claude-cli-config.json         # Reference config
├── claude-desktop-config.json     # Reference config
└── README.md
```

## Stopping

```bash
./scripts/stop.sh
```

Model data persists in Docker volumes. To fully remove: `docker volume rm gemma4-with-vscode_ollama_data`
