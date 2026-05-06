# ─────────────────────────────────────────────────────────────
# Gemma 4 E4B — Unified Docker Image
# Combines Ollama (LLM runtime) + MCP Server (SSE transport)
#
# Ports:
#   11434 — Ollama API (OpenAI-compatible)
#   3001  — MCP Server (SSE transport for Claude Desktop/CLI)
#
# Build:   docker build -t gemma4-unified .
# Run:     docker run -d -p 11434:11434 -p 3001:3001 \
#            -v ollama_data:/root/.ollama \
#            --shm-size=4g --name gemma4 gemma4-unified
# ─────────────────────────────────────────────────────────────

FROM ollama/ollama:latest

# ─── Install Node.js 20 LTS ──────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ─── Copy MCP server ─────────────────────────────────────────
WORKDIR /app/mcp-server
COPY mcp-server/package.json mcp-server/package-lock.json* ./
RUN npm ci --production 2>/dev/null || npm install --production
COPY mcp-server/index.js mcp-server/index-sse.js ./

# ─── Copy entrypoint script ──────────────────────────────────
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# ─── Environment defaults ────────────────────────────────────
# These are safe defaults for CPU (Mac + GCP).
# On GCP x86_64 you can override at runtime:
#   OLLAMA_FLASH_ATTENTION=true   (safe on x86_64, crashes on ARM64 Docker)
#   OLLAMA_CONTEXT_LENGTH=8192    (GCP VMs typically have more RAM)
#   OLLAMA_LLM_LIBRARY=           (auto-detect; set "cpu" only if GPU causes issues)
ENV OLLAMA_HOST=0.0.0.0 \
    OLLAMA_ORIGINS=* \
    OLLAMA_NUM_PARALLEL=1 \
    OLLAMA_MAX_LOADED_MODELS=1 \
    OLLAMA_KV_CACHE_TYPE=q4_0 \
    OLLAMA_CONTEXT_LENGTH=4096 \
    OLLAMA_FLASH_ATTENTION=false \
    OLLAMA_LLM_LIBRARY=cpu \
    OLLAMA_BASE_URL=http://localhost:11434 \
    GEMMA_MODEL=gemma4:e4b \
    MCP_PORT=3001

# ─── Expose ports ────────────────────────────────────────────
EXPOSE 11434 3001

# ─── Health check (checks both Ollama + MCP) ─────────────────
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=30s \
  CMD curl -sf http://localhost:11434/api/tags > /dev/null && \
      curl -sf http://localhost:3001/health > /dev/null

ENTRYPOINT ["/docker-entrypoint.sh"]
