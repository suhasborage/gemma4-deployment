#!/bin/bash
# start.sh - Start Gemma 4 E4B via Ollama in Docker
# Compatible with Rancher Desktop (moby engine)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

MODEL="gemma4:e4b"

echo "🚀 Starting Gemma 4 E4B Local AI Stack..."
echo "============================================"

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Rancher Desktop first."
    exit 1
fi

# --- Pull the Ollama image (with fallback for registry issues) ---
echo "📦 Checking Ollama image..."
if ! docker image inspect ollama/ollama:latest > /dev/null 2>&1; then
    echo "📥 Pulling Ollama image..."

    # Try 1: Standard docker pull
    if docker pull ollama/ollama:latest 2>/dev/null; then
        echo "   ✅ Pulled via docker pull"
    else
        echo "   ⚠️  docker pull failed (registry timeout). Trying alternative methods..."

        # Try 2: Pull via rdctl shell (Rancher Desktop VM has network access)
        if command -v rdctl > /dev/null 2>&1; then
            echo "   🔄 Attempting pull via Rancher Desktop VM (rdctl)..."
            rdctl shell sh -c "ctr -n docker images pull docker.io/ollama/ollama:latest" 2>/dev/null && \
                echo "   ✅ Pulled via rdctl" || true
        fi

        # Try 3: Pull with Google mirror
        if ! docker image inspect ollama/ollama:latest > /dev/null 2>&1; then
            echo "   🔄 Attempting pull via Google mirror..."
            docker pull mirror.gcr.io/ollama/ollama:latest 2>/dev/null && \
                docker tag mirror.gcr.io/ollama/ollama:latest ollama/ollama:latest 2>/dev/null && \
                echo "   ✅ Pulled via mirror" || true
        fi

        # Final check
        if ! docker image inspect ollama/ollama:latest > /dev/null 2>&1; then
            echo ""
            echo "   ❌ Could not pull ollama/ollama:latest via any method."
            echo ""
            echo "   Manual fix options:"
            echo "   1. Disconnect VPN and retry: ./scripts/start.sh"
            echo "   2. Pull via Rancher Desktop VM shell:"
            echo "      rdctl shell"
            echo "      ctr -n docker images pull docker.io/ollama/ollama:latest"
            echo "      exit"
            echo "      ./scripts/start.sh"
            echo "   3. Configure proxy in Rancher Desktop:"
            echo "      Preferences → Application → Proxy"
            exit 1
        fi
    fi
else
    echo "   ✅ Ollama image already available"
fi

# Start Ollama container
echo ""
echo "📦 Starting Ollama container..."
cd "$PROJECT_DIR"
docker compose up -d ollama

# Wait for Ollama to be healthy
echo "⏳ Waiting for Ollama to be ready..."
for i in {1..30}; do
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ Ollama is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Ollama failed to start. Check: docker logs gemma4-ollama"
        exit 1
    fi
    sleep 2
done

# Pull Gemma 4 E4B model (if not already pulled)
echo ""
echo "📥 Checking Gemma 4 E4B model..."
if ! docker exec gemma4-ollama ollama list 2>/dev/null | grep -q "gemma4"; then
    echo "📥 Pulling $MODEL (~9.6GB, this may take a few minutes on first run)..."
    docker exec gemma4-ollama ollama pull "$MODEL"
    echo "✅ Model downloaded!"
else
    echo "✅ Gemma 4 model already available."
fi

# Show available models
echo ""
echo "📋 Installed models:"
docker exec gemma4-ollama ollama list

echo ""
echo "============================================"
echo "🎉 Gemma 4 E4B is ready!"
echo ""
echo "📡 API Endpoints:"
echo "   Ollama API:    http://localhost:11434"
echo "   OpenAI compat: http://localhost:11434/v1"
echo ""
echo "🧪 Quick test:"
echo "   curl http://localhost:11434/v1/chat/completions \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"model\":\"gemma4:e4b\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}]}'"
echo ""
echo "🛑 To stop: ./scripts/stop.sh"
echo "============================================"
