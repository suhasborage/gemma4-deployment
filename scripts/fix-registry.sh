#!/bin/bash
# fix-registry.sh - Diagnose and fix Docker registry access issues with Rancher Desktop
set -e

echo "🔍 Diagnosing Docker Registry Access..."
echo "========================================="

# Step 1: Check if it's a DNS issue
echo ""
echo "1️⃣  DNS Resolution Test..."
if nslookup registry-1.docker.io > /dev/null 2>&1; then
    echo "   ✅ DNS resolves registry-1.docker.io"
    nslookup registry-1.docker.io | grep -A1 "Name:"
else
    echo "   ❌ DNS cannot resolve registry-1.docker.io"
    echo "   → Try: Settings → Network in Rancher Desktop"
fi

# Step 2: Check connectivity
echo ""
echo "2️⃣  Network Connectivity Test..."
if curl -sf --connect-timeout 10 https://registry-1.docker.io/v2/ > /dev/null 2>&1; then
    echo "   ✅ Can reach Docker Hub registry"
elif curl -sf --connect-timeout 10 https://registry-1.docker.io/v2/ 2>&1 | grep -q "UNAUTHORIZED"; then
    echo "   ✅ Can reach Docker Hub (got auth challenge - this is normal)"
else
    echo "   ❌ Cannot reach registry-1.docker.io (timeout or blocked)"
    echo ""
    echo "   Possible causes:"
    echo "   a) Corporate proxy/firewall blocking Docker Hub"
    echo "   b) Rancher Desktop VM networking misconfigured"
    echo "   c) VPN interfering with container networking"
fi

# Step 3: Check proxy settings
echo ""
echo "3️⃣  Proxy Environment..."
if [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ] || [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
    echo "   Proxy detected:"
    [ -n "$HTTP_PROXY" ] && echo "   HTTP_PROXY=$HTTP_PROXY"
    [ -n "$HTTPS_PROXY" ] && echo "   HTTPS_PROXY=$HTTPS_PROXY"
    [ -n "$http_proxy" ] && echo "   http_proxy=$http_proxy"
    [ -n "$https_proxy" ] && echo "   https_proxy=$https_proxy"
    echo ""
    echo "   → Docker needs proxy config too. See fixes below."
else
    echo "   No proxy environment variables set on host."
    echo "   (But Rancher Desktop VM may still need proxy config)"
fi

# Step 4: Check Rancher Desktop engine
echo ""
echo "4️⃣  Rancher Desktop Engine..."
if command -v rdctl > /dev/null 2>&1; then
    ENGINE=$(rdctl list-settings 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('containerEngine',{}).get('name','unknown'))" 2>/dev/null || echo "unknown")
    echo "   Container engine: $ENGINE"
else
    echo "   rdctl not found (can't query Rancher Desktop settings)"
fi

# Step 5: Test from inside the VM
echo ""
echo "5️⃣  Testing from inside Rancher Desktop VM..."
INSIDE_RESULT=$(docker run --rm --network host alpine:3.18 sh -c "wget -q --spider --timeout=10 https://registry-1.docker.io/v2/ 2>&1" 2>&1) || true
if echo "$INSIDE_RESULT" | grep -q "401"; then
    echo "   ✅ VM can reach Docker Hub (got 401 - normal)"
elif echo "$INSIDE_RESULT" | grep -qi "error\|timeout\|resolve"; then
    echo "   ❌ VM cannot reach Docker Hub from inside"
    echo "   Result: $INSIDE_RESULT"
else
    echo "   ⚠️  Uncertain. Result: $INSIDE_RESULT"
fi

echo ""
echo "========================================="
echo "🛠️  FIXES TO TRY (in order):"
echo "========================================="
echo ""
echo "FIX 1: Restart Rancher Desktop networking"
echo "   → Quit Rancher Desktop → Reopen → Wait 30s → Try again"
echo ""
echo "FIX 2: Use Docker Hub mirror (bypasses direct registry access)"
echo "   → In Rancher Desktop: Preferences → Container Engine → Allowed Images"
echo "   → Or add registry mirror (see below)"
echo ""
echo "FIX 3: Configure proxy in Rancher Desktop"
echo "   → Preferences → Application → Proxy"
echo "   → Set HTTP/HTTPS proxy if you're behind a corporate proxy"
echo "   → Add NO_PROXY=localhost,127.0.0.1"
echo ""
echo "FIX 4: Add Docker Hub mirror to daemon.json"
echo "   Create/edit: ~/.config/rancher-desktop/docker/daemon.json"
echo '   {'
echo '     "registry-mirrors": ["https://mirror.gcr.io"]'
echo '   }'
echo "   Then restart Rancher Desktop."
echo ""
echo "FIX 5: If on VPN, try split-tunneling or disconnecting VPN"
echo "   Many VPNs break container DNS/routing."
echo ""
echo "FIX 6: Switch Rancher Desktop network mode"
echo "   → Preferences → Virtual Machine → Network"
echo "   → Try toggling between 'socket-vmnet' and 'vzNAT'"
echo "   → Restart Rancher Desktop"
echo ""
echo "FIX 7: Pull image on host then load into Rancher"
echo "   If all else fails, download the image file manually:"
echo "   → Visit: https://hub.docker.com/r/ollama/ollama/tags"
echo "   → Or use: nerdctl pull ollama/ollama:latest (if nerdctl works)"
echo ""
echo "========================================="
