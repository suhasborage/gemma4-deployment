#!/bin/bash
# start-unified.sh — Start Gemma 4 E4B + MCP Server in a single Docker container
# Both Ollama API and MCP SSE endpoint exposed from one container
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Starting Gemma 4 E4B Unified Stack..."
echo "============================================"
echo "  This starts BOTH Ollama + MCP Server"
echo "  in a single Docker container."
echo "============================================"

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Rancher Desktop first."
    exit 1
fi

# Stop any existing containers that use the same ports
echo ""
echo "📦 Checking for port conflicts..."
if docker ps -q --filter "name=gemma4-ollama" | grep -q .; then
    echo "   Stopping existing gemma4-ollama container..."
    docker stop gemma4-ollama 2>/dev/null || true
fi
if docker ps -q --filter "name=gemma4-unified" | grep -q .; then
    echo "   Stopping existing gemma4-unified container..."
    docker stop gemma4-unified 2>/dev/null || true
fi

# Build the unified image
echo ""
echo "🔨 Building unified Docker image..."
cd "$PROJECT_DIR"
docker compose --profile unified build

# Start the unified container
echo ""
echo "📦 Starting unified container..."
docker compose --profile unified up -d gemma4-unified

# Wait for both services to be healthy
echo ""
echo "⏳ Waiting for services to be ready..."
echo "   (First run pulls gemma4:e4b model — may take several minutes)"
MAX_WAIT=300  # 5 minutes for first run (model pull)
for i in $(seq 1 $MAX_WAIT); do
    OLLAMA_OK=false
    MCP_OK=false

    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        OLLAMA_OK=true
    fi
    if curl -sf http://localhost:3001/health > /dev/null 2>&1; then
        MCP_OK=true
    fi

    if $OLLAMA_OK && $MCP_OK; then
        echo ""
        echo "✅ Both services are ready!"
        break
    fi

    if [ $i -eq $MAX_WAIT ]; then
        echo ""
        echo "⚠️  Timeout waiting for services."
        echo "   Ollama: $( $OLLAMA_OK && echo '✅' || echo '❌' )"
        echo "   MCP:    $( $MCP_OK && echo '✅' || echo '❌' )"
        echo ""
        echo "   Check logs: docker logs gemma4-unified"
        exit 1
    fi

    # Progress indicator every 10 seconds
    if [ $((i % 10)) -eq 0 ]; then
        echo "   Still waiting... (${i}s) Ollama=$( $OLLAMA_OK && echo 'ok' || echo 'starting' ) MCP=$( $MCP_OK && echo 'ok' || echo 'starting' )"
    fi
    sleep 1
done

# Show installed models
echo ""
echo "📋 Installed models:"
curl -sf http://localhost:11434/api/tags | python3 -c "
import json, sys
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(f'   - {m[\"name\"]} ({m.get(\"size\",0)//1024//1024}MB)')
" 2>/dev/null || echo "   (could not list models)"

# Show MCP health
echo ""
echo "🔍 MCP Server health:"
curl -sf http://localhost:3001/health | python3 -c "
import json, sys
data = json.load(sys.stdin)
for k, v in data.items():
    print(f'   {k}: {v}')
" 2>/dev/null || echo "   (could not reach MCP)"

echo ""
echo "============================================"
echo "🎉 Gemma 4 E4B Unified Stack is ready!"
echo ""
echo "📡 Endpoints (single container):"
echo "   Ollama API:    http://localhost:11434"
echo "   OpenAI compat: http://localhost:11434/v1"
echo "   MCP SSE:       http://localhost:3001/sse"
echo "   MCP Health:    http://localhost:3001/health"
echo ""
echo "🔧 Claude Desktop config (SSE transport):"
echo '   Add to ~/Library/Application Support/Claude/claude_desktop_config.json:'
echo '   {'
echo '     "mcpServers": {'
echo '       "gemma4-local": {'
echo '         "url": "http://localhost:3001/sse"'
echo '       }'
echo '     }'
echo '   }'
echo ""
echo "🧪 Quick test:"
echo "   curl http://localhost:3001/health"
echo "   curl http://localhost:11434/v1/chat/completions \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"model\":\"gemma4:e4b\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}'"
echo ""
echo "🛑 To stop: docker compose --profile unified down"
echo "============================================"
