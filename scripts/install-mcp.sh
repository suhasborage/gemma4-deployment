#!/bin/bash
# install-mcp.sh - Install MCP server dependencies and configure Claude CLI/Desktop
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MCP_DIR="$PROJECT_DIR/mcp-server"

echo "📦 Installing MCP Server dependencies..."
cd "$MCP_DIR"
npm install

echo ""
echo "✅ MCP Server installed!"
echo ""
echo "============================================"
echo "📋 CONFIGURATION INSTRUCTIONS"
echo "============================================"
echo ""
echo "1️⃣  FOR CLAUDE CLI:"
echo "   Add to ~/.claude/settings.json (or project .claude/settings.json):"
echo ""
echo '   "mcpServers": {'
echo '     "gemma4-local": {'
echo '       "command": "node",'
echo "       \"args\": [\"$MCP_DIR/index.js\"],"
echo '       "env": {'
echo '         "OLLAMA_BASE_URL": "http://localhost:11434",'
echo '         "GEMMA_MODEL": "gemma4:e4b"'
echo '       }'
echo '     }'
echo '   }'
echo ""
echo "2️⃣  FOR CLAUDE DESKTOP:"
echo "   Add to ~/Library/Application Support/Claude/claude_desktop_config.json:"
echo "   (Same mcpServers block as above)"
echo ""
echo "3️⃣  TEST IT:"
echo "   claude> Use gemma4_chat to say hello"
echo "   claude> Use gemma4_code to write a fibonacci function in python"
echo ""
echo "============================================"
