# Gemma 4 E4B — VS Code Configuration (Continue Extension)

## What This Does

Configures VS Code to use Gemma 4 E4B as a local AI coding assistant via the
**Continue** extension. You get: inline chat, tab autocomplete, code review,
and custom slash commands — all powered by Gemma 4 running on your machine.

## Prerequisites

1. Ollama running with Gemma 4 E4B (run `./scripts/start.sh` first)
2. VS Code installed
3. Node.js 18+ (for Continue extension)

## Step-by-Step Setup

### Step 1: Install Continue Extension

**Option A — VS Code Marketplace:**
1. Open VS Code
2. Go to Extensions (Cmd+Shift+X)
3. Search for **"Continue"**
4. Install **Continue - Codestral, Claude, and more** by Continue.dev

**Option B — Terminal:**
```bash
code --install-extension continue.continue
```

### Step 2: Configure Continue for Gemma 4

**Option A — Copy the provided config:**
```bash
# This copies the pre-configured config to your home directory
cp -r ~/work/innovation/cowork/gemma4-with-vscode/.continue ~/.continue
```

**Option B — Manual configuration:**
1. Open VS Code
2. Press **Cmd+L** to open the Continue sidebar
3. Click the gear icon (⚙️) at the bottom of the sidebar
4. Replace the config with:

```json
{
  "models": [
    {
      "title": "Gemma 4 E4B (Local)",
      "provider": "ollama",
      "model": "gemma4:e4b",
      "apiBase": "http://localhost:11434",
      "completionOptions": {
        "temperature": 0.7,
        "maxTokens": 2048
      }
    }
  ],
  "tabAutocompleteModel": {
    "title": "Gemma 4 Autocomplete",
    "provider": "ollama",
    "model": "gemma4:e4b",
    "apiBase": "http://localhost:11434",
    "completionOptions": {
      "temperature": 0.2,
      "maxTokens": 256
    }
  },
  "customCommands": [
    {
      "name": "review",
      "description": "Review the selected code for issues",
      "prompt": "Review this code for bugs, security issues, and improvements. Be specific and actionable:\n\n{{{ input }}}"
    },
    {
      "name": "explain",
      "description": "Explain what the selected code does",
      "prompt": "Explain this code clearly and concisely. Cover what it does, how it works, and any notable patterns:\n\n{{{ input }}}"
    },
    {
      "name": "refactor",
      "description": "Suggest refactoring improvements",
      "prompt": "Suggest refactoring improvements for this code. Focus on readability, performance, and best practices:\n\n{{{ input }}}"
    },
    {
      "name": "tests",
      "description": "Generate unit tests for selected code",
      "prompt": "Write comprehensive unit tests for this code. Cover edge cases and use appropriate assertions:\n\n{{{ input }}}"
    }
  ],
  "contextProviders": [
    { "name": "diff", "params": {} },
    { "name": "open", "params": {} },
    { "name": "terminal", "params": {} }
  ],
  "slashCommands": [
    { "name": "commit", "description": "Generate a commit message" },
    { "name": "comment", "description": "Add comments to code" },
    { "name": "share", "description": "Export conversation as markdown" }
  ]
}
```

### Step 3: Configure VS Code Settings

Open VS Code Settings (Cmd+,) and add:

```json
{
  "continue.enableTabAutocomplete": true,
  "continue.telemetryEnabled": false,
  "editor.inlineSuggest.enabled": true,
  "editor.suggest.preview": true
}
```

Or copy from the project:
```bash
# Copy VS Code settings to your project
cp -r ~/work/innovation/cowork/gemma4-with-vscode/vscode-settings .vscode
```

### Step 4: Verify

1. Open a code file in VS Code
2. Press **Cmd+L** — the Continue sidebar should show "Gemma 4 E4B (Local)"
3. Type a question like "What does this file do?"
4. Start typing code — you should see autocomplete suggestions from Gemma 4

## Usage Guide

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+L** | Open Continue chat sidebar |
| **Cmd+I** | Inline edit with AI (edit code in-place) |
| **Tab** | Accept autocomplete suggestion |
| **Cmd+Shift+L** | Add selected code to chat context |
| **Cmd+Shift+R** | Refactor selected code |

### Custom Slash Commands

Select code, press Cmd+L, then type:

| Command | What it does |
|---------|-------------|
| `/review` | Security + bug review of selected code |
| `/explain` | Plain-English explanation of selected code |
| `/refactor` | Refactoring suggestions |
| `/tests` | Generate unit tests |
| `/commit` | Generate a commit message from diff |
| `/comment` | Add inline comments to code |

### Context Providers

Continue automatically includes context from:
- **@diff** — Current git diff
- **@open** — Currently open files
- **@terminal** — Recent terminal output

Use these in chat: `@diff What changed in my last commit?`

## Adding Multiple Models (Optional)

You can add Gemma 4 alongside other models (e.g., the larger 26B variant):

```json
{
  "models": [
    {
      "title": "Gemma 4 E4B (Fast)",
      "provider": "ollama",
      "model": "gemma4:e4b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Gemma 4 26B (Quality)",
      "provider": "ollama",
      "model": "gemma4:26b",
      "apiBase": "http://localhost:11434"
    }
  ]
}
```

Switch between models using the dropdown at the top of the Continue sidebar.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Could not connect to Ollama" | Verify Ollama is running: `curl http://localhost:11434` |
| No autocomplete suggestions | Check `continue.enableTabAutocomplete` is `true` in VS Code settings |
| Slow autocomplete | Normal for first few suggestions (model loading). Reduce `maxTokens` to 128 |
| Continue sidebar empty | Click the Continue icon in the sidebar, or run "Continue: Focus on Continue View" from command palette |
| Model dropdown shows nothing | Verify `~/.continue/config.json` has valid JSON (no trailing commas) |
