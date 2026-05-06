#!/bin/bash
# ─────────────────────────────────────────────────────────────
# docker-entrypoint.sh — Starts Ollama + MCP Server
#
# 1. Launches Ollama server in background
# 2. Waits for Ollama to be ready
# 3. Pulls Gemma 4 E4B model if not already present
# 4. Starts MCP SSE server in background
# 5. Monitors both processes (exits if either dies)
# ─────────────────────────────────────────────────────────────
set -e

MODEL="${GEMMA_MODEL:-gemma4:e4b}"
MCP_PORT="${MCP_PORT:-3001}"

echo "════════════════════════════════════════════════"
echo "  Gemma 4 E4B — Unified Container"
echo "  Ollama API:  http://0.0.0.0:11434"
echo "  MCP Server:  http://0.0.0.0:${MCP_PORT}/sse"
echo "════════════════════════════════════════════════"

# ─── 1. Start Ollama ─────────────────────────────────────────
echo "[1/4] Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

# ─── 2. Wait for Ollama to be ready ──────────────────────────
echo "[2/4] Waiting for Ollama to be ready..."
MAX_RETRIES=60
for i in $(seq 1 $MAX_RETRIES); do
  if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "       Ollama is ready! (took ${i}s)"
    break
  fi
  if [ $i -eq $MAX_RETRIES ]; then
    echo "ERROR: Ollama failed to start after ${MAX_RETRIES}s"
    exit 1
  fi
  sleep 1
done

# ─── 3. Pull model if needed ─────────────────────────────────
echo "[3/4] Checking model: ${MODEL}..."
if ! ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
  echo "       Pulling ${MODEL} (this may take several minutes on first run)..."
  ollama pull "$MODEL"
  echo "       Model ready!"
else
  echo "       Model already available."
fi

# ─── 4. Start MCP SSE Server ─────────────────────────────────
echo "[4/4] Starting MCP SSE server on port ${MCP_PORT}..."
cd /app/mcp-server
node index-sse.js &
MCP_PID=$!

# Wait a moment and verify MCP started
sleep 2
if ! kill -0 $MCP_PID 2>/dev/null; then
  echo "ERROR: MCP server failed to start"
  exit 1
fi

echo ""
echo "════════════════════════════════════════════════"
echo "  All services running!"
echo ""
echo "  Ollama API:       http://localhost:11434"
echo "  OpenAI compat:    http://localhost:11434/v1"
echo "  MCP SSE:          http://localhost:${MCP_PORT}/sse"
echo "  MCP Health:       http://localhost:${MCP_PORT}/health"
echo "  Model:            ${MODEL}"
echo "════════════════════════════════════════════════"
echo ""

# ─── Monitor both processes ───────────────────────────────────
# If either process dies, the container exits
cleanup() {
  echo "Shutting down..."
  kill $MCP_PID 2>/dev/null || true
  kill $OLLAMA_PID 2>/dev/null || true
  wait
  exit 0
}
trap cleanup SIGINT SIGTERM

# Wait for either process to exit
while true; do
  if ! kill -0 $OLLAMA_PID 2>/dev/null; then
    echo "ERROR: Ollama process died!"
    kill $MCP_PID 2>/dev/null || true
    exit 1
  fi
  if ! kill -0 $MCP_PID 2>/dev/null; then
    echo "ERROR: MCP server process died!"
    kill $OLLAMA_PID 2>/dev/null || true
    exit 1
  fi
  sleep 5
done
