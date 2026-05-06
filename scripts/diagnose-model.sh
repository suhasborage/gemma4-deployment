#!/bin/bash
# diagnose-model.sh - Check what's actually running in Ollama
echo "🔍 Diagnosing Ollama + Gemma 4..."
echo "================================="

echo ""
echo "1️⃣  Ollama health..."
if curl -sf http://localhost:11434/ > /dev/null 2>&1; then
    echo "   ✅ Ollama is responding"
else
    echo "   ❌ Ollama not responding on port 11434"
    exit 1
fi

echo ""
echo "2️⃣  Installed models..."
curl -sf http://localhost:11434/api/tags | python3 -c "
import json, sys
data = json.load(sys.stdin)
models = data.get('models', [])
if not models:
    print('   ⚠️  No models installed!')
    print('   Run: docker exec gemma4-ollama ollama pull gemma4:e4b')
else:
    for m in models:
        print(f'   - {m[\"name\"]} ({m.get(\"size\",0)//1024//1024}MB)')
" 2>/dev/null || echo "   ❌ Could not parse model list"

echo ""
echo "3️⃣  Testing with Ollama native API (not OpenAI compat)..."
RESULT=$(curl -sf --max-time 60 http://localhost:11434/api/generate \
    -d '{"model":"gemma4:e4b","prompt":"Say hello","stream":false}' 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "$RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'error' in data:
    print(f'   ❌ Ollama error: {data[\"error\"]}')
else:
    print(f'   ✅ Response: {data.get(\"response\",\"\")[:200]}')
" 2>/dev/null
else
    echo "   ❌ Request failed (exit code $EXIT_CODE)"
    echo "   Raw: $RESULT"
fi

echo ""
echo "4️⃣  Testing OpenAI-compatible endpoint..."
RESULT=$(curl -sf --max-time 60 http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"gemma4:e4b","messages":[{"role":"user","content":"Say hello"}],"max_tokens":20}' 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "$RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'error' in data:
    print(f'   ❌ Error: {data[\"error\"]}')
else:
    msg = data.get('choices',[{}])[0].get('message',{}).get('content','')
    print(f'   ✅ Response: {msg[:200]}')
" 2>/dev/null
else
    echo "   ❌ Request failed (exit code $EXIT_CODE)"
fi

echo ""
echo "5️⃣  Container architecture check..."
ARCH=$(docker exec gemma4-ollama uname -m 2>/dev/null || echo "unknown")
echo "   Container arch: $ARCH"
if [ "$ARCH" = "aarch64" ]; then
    echo "   ✅ Running native ARM64"
elif [ "$ARCH" = "x86_64" ]; then
    echo "   ⚠️  Running x86_64 under Rosetta emulation!"
    echo "   This can cause crashes. Fix: In Rancher Desktop →"
    echo "   Preferences → Virtual Machine → Emulation → disable Rosetta"
fi

echo ""
echo "6️⃣  Docker container logs (last 20 lines)..."
docker logs gemma4-ollama --tail 20 2>&1 | sed 's/^/   /'

echo ""
echo "================================="
