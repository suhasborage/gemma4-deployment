#!/bin/bash
# stop.sh - Stop the Gemma 4 local AI stack
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🛑 Stopping Gemma 4 E4B stack..."
cd "$PROJECT_DIR"
docker compose down

echo "✅ All containers stopped."
echo "   Model data is preserved in Docker volumes."
echo "   To remove model data: docker volume rm gemma4-with-vscode_ollama_data"
