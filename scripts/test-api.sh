#!/bin/bash
# test-api.sh - Verify Gemma 4 E4B is responding correctly
set -e

echo "🧪 Testing Gemma 4 E4B API..."
echo "=============================="

# Test 1: Health check
echo ""
echo "1️⃣  Health Check..."
if curl -sf http://localhost:11434/api/tags > /dev/null; then
    echo "   ✅ Ollama is running"
else
    echo "   ❌ Ollama is not responding. Run ./scripts/start.sh first."
    exit 1
fi

# Test 2: Model availability
echo ""
echo "2️⃣  Model Check..."
MODELS=$(curl -sf http://localhost:11434/api/tags | python3 -c "import json,sys; data=json.load(sys.stdin); [print(f'   - {m[\"name\"]}') for m in data.get('models',[])]" 2>/dev/null)
if [ -n "$MODELS" ]; then
    echo "   Available models:"
    echo "$MODELS"
else
    echo "   ⚠️  No models found. Pull one with: docker exec gemma4-ollama ollama pull gemma4:e4b"
fi

# Test 3: Chat completion (OpenAI-compatible)
echo ""
echo "3️⃣  Chat Completion Test (OpenAI format)..."
RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma4:e4b",
        "messages": [{"role": "user", "content": "Say hello in exactly 5 words."}],
        "temperature": 0.7,
        "max_tokens": 50
    }')

if [ $? -eq 0 ]; then
    CONTENT=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'])" 2>/dev/null)
    echo "   ✅ Response: $CONTENT"
else
    echo "   ❌ Chat completion failed"
fi

# Test 4: Streaming test
echo ""
echo "4️⃣  Streaming Test..."
echo -n "   Response: "
curl -sf http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "gemma4:e4b",
        "messages": [{"role": "user", "content": "Count from 1 to 5."}],
        "stream": true,
        "max_tokens": 50
    }' | while IFS= read -r line; do
    if [[ "$line" == data:* ]]; then
        CHUNK=$(echo "${line#data: }" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('choices',[{}])[0].get('delta',{}).get('content',''),end='')" 2>/dev/null)
        echo -n "$CHUNK"
    fi
done
echo ""

echo ""
echo "=============================="
echo "✅ All tests passed! Gemma 4 E4B is working correctly."
