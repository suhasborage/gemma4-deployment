#!/bin/bash
# ─────────────────────────────────────────────────────────────
# gcp-deploy.sh — Deploy Gemma 4 E4B + MCP Server to GCP
#
# Creates a GCE VM with Docker, builds the unified container,
# and sets up IAP tunnel for secure localhost-only access.
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - A GCP project with billing enabled
#   - Compute Engine API enabled
#
# Usage:
#   ./scripts/gcp-deploy.sh              # Create VM + deploy
#   ./scripts/gcp-deploy.sh --connect    # SSH tunnel to existing VM
#   ./scripts/gcp-deploy.sh --destroy    # Delete VM
# ─────────────────────────────────────────────────────────────
set -e

# ─── Configuration (edit these) ───────────────────────────────
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
ZONE="${GCP_ZONE:-us-central1-a}"
VM_NAME="${GCP_VM_NAME:-gemma4-vm}"
MACHINE_TYPE="${GCP_MACHINE_TYPE:-e2-standard-8}"   # 8 vCPU, 32 GB RAM
DISK_SIZE="${GCP_DISK_SIZE:-50}"                      # GB
DISK_TYPE="pd-ssd"

echo "════════════════════════════════════════════════"
echo "  Gemma 4 E4B — GCP Deployment"
echo "  Project: ${PROJECT_ID}"
echo "  Zone:    ${ZONE}"
echo "  VM:      ${VM_NAME} (${MACHINE_TYPE})"
echo "════════════════════════════════════════════════"

# ─── Parse arguments ──────────────────────────────────────────
if [ "$1" = "--connect" ]; then
    echo ""
    echo "🔗 Opening IAP tunnel to ${VM_NAME}..."
    echo "   Ollama API → http://localhost:11434"
    echo "   MCP SSE    → http://localhost:3001"
    echo "   Press Ctrl+C to disconnect."
    echo ""
    # Forward both ports through IAP tunnel (secure, no public IP needed)
    gcloud compute ssh "$VM_NAME" \
        --project="$PROJECT_ID" \
        --zone="$ZONE" \
        --tunnel-through-iap \
        -- -N \
           -L 11434:localhost:11434 \
           -L 3001:localhost:3001
    exit 0
fi

if [ "$1" = "--destroy" ]; then
    echo ""
    echo "🗑️  Deleting VM ${VM_NAME}..."
    gcloud compute instances delete "$VM_NAME" \
        --project="$PROJECT_ID" \
        --zone="$ZONE" \
        --quiet
    echo "✅ VM deleted. Persistent disk data is gone."
    exit 0
fi

# ─── Preflight checks ────────────────────────────────────────
if [ -z "$PROJECT_ID" ]; then
    echo "❌ No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q .; then
    echo "❌ Not authenticated. Run: gcloud auth login"
    exit 1
fi

echo ""
echo "🔍 Checking prerequisites..."
gcloud services enable compute.googleapis.com --project="$PROJECT_ID" 2>/dev/null || true
echo "   ✅ Compute Engine API enabled"

# ─── Create the startup script ────────────────────────────────
# This runs on the VM when it first boots
STARTUP_SCRIPT='#!/bin/bash
set -e
exec > /var/log/gemma4-startup.log 2>&1

echo "=== Gemma 4 startup script ==="
date

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker $(whoami) 2>/dev/null || true
fi

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose plugin
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    apt-get update -qq
    apt-get install -y -qq docker-compose-plugin
fi

# Install git to clone repo
apt-get install -y -qq git

# Clone or update the repo
REPO_DIR="/opt/gemma4-with-vscode"
if [ -d "$REPO_DIR/.git" ]; then
    cd "$REPO_DIR" && git pull
else
    # The repo will be synced via gcloud scp; create placeholder
    mkdir -p "$REPO_DIR"
fi

echo "=== Docker ready, waiting for repo sync ==="
date
'

# ─── Create VM ────────────────────────────────────────────────
echo ""
echo "📦 Creating VM: ${VM_NAME}..."

# Check if VM already exists
if gcloud compute instances describe "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" &>/dev/null; then
    echo "   ⚠️  VM already exists. Use --destroy to recreate, or --connect to tunnel."
    echo "   Continuing with existing VM..."
else
    gcloud compute instances create "$VM_NAME" \
        --project="$PROJECT_ID" \
        --zone="$ZONE" \
        --machine-type="$MACHINE_TYPE" \
        --boot-disk-size="${DISK_SIZE}GB" \
        --boot-disk-type="$DISK_TYPE" \
        --image-family="ubuntu-2204-lts" \
        --image-project="ubuntu-os-cloud" \
        --no-address \
        --tags="gemma4-iap" \
        --metadata=startup-script="$STARTUP_SCRIPT" \
        --scopes="default"

    echo "   ✅ VM created (no external IP — access via IAP tunnel only)"
fi

# ─── Create firewall rule for IAP ─────────────────────────────
echo ""
echo "🔒 Configuring IAP tunnel firewall..."
if ! gcloud compute firewall-rules describe allow-iap-gemma4 --project="$PROJECT_ID" &>/dev/null; then
    gcloud compute firewall-rules create allow-iap-gemma4 \
        --project="$PROJECT_ID" \
        --direction=INGRESS \
        --action=ALLOW \
        --rules=tcp:22 \
        --source-ranges="35.235.240.0/20" \
        --target-tags="gemma4-iap" \
        --description="Allow IAP tunnel SSH for Gemma 4 VM"
    echo "   ✅ IAP firewall rule created"
else
    echo "   ✅ IAP firewall rule already exists"
fi

# ─── Wait for VM to be ready ──────────────────────────────────
echo ""
echo "⏳ Waiting for VM to boot and install Docker..."
for i in $(seq 1 60); do
    if gcloud compute ssh "$VM_NAME" \
        --project="$PROJECT_ID" \
        --zone="$ZONE" \
        --tunnel-through-iap \
        --command="docker --version" &>/dev/null; then
        echo "   ✅ VM is ready with Docker!"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "   ⚠️  Timeout waiting for Docker. SSH in manually to check."
    fi
    sleep 5
done

# ─── Sync project files to VM ─────────────────────────────────
echo ""
echo "📤 Syncing project files to VM..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Create a tarball of just the needed files
cd "$PROJECT_DIR"
tar czf /tmp/gemma4-deploy.tar.gz \
    --exclude=node_modules \
    --exclude=.git \
    --exclude='*.pptx' \
    --exclude='*.pdf' \
    --exclude='*.docx' \
    --exclude='*.jpg' \
    Dockerfile \
    .dockerignore \
    docker-compose.yml \
    mcp-server/package.json \
    mcp-server/package-lock.json \
    mcp-server/index.js \
    mcp-server/index-sse.js \
    scripts/docker-entrypoint.sh \
    2>/dev/null || true

gcloud compute scp /tmp/gemma4-deploy.tar.gz "$VM_NAME":/tmp/ \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --tunnel-through-iap

# Extract and build on VM
echo ""
echo "🔨 Building unified container on VM..."
gcloud compute ssh "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --tunnel-through-iap \
    --command="
set -e
sudo mkdir -p /opt/gemma4-with-vscode
cd /opt/gemma4-with-vscode
sudo tar xzf /tmp/gemma4-deploy.tar.gz
sudo chmod +x scripts/docker-entrypoint.sh

echo '--- Building Docker image ---'
sudo docker compose --profile unified build

echo '--- Starting unified container ---'
sudo docker compose --profile unified up -d gemma4-unified

echo '--- Waiting for services ---'
for i in \$(seq 1 180); do
    OLLAMA=\$(curl -sf http://localhost:11434/api/tags > /dev/null 2>&1 && echo 'ok' || echo 'starting')
    MCP=\$(curl -sf http://localhost:3001/health > /dev/null 2>&1 && echo 'ok' || echo 'starting')
    if [ \"\$OLLAMA\" = 'ok' ] && [ \"\$MCP\" = 'ok' ]; then
        echo \"Services ready after \${i}s\"
        break
    fi
    if [ \$i -eq 180 ]; then
        echo 'Timeout — check: sudo docker logs gemma4-unified'
    fi
    if [ \$((i % 15)) -eq 0 ]; then
        echo \"  Waiting... (\${i}s) Ollama=\$OLLAMA MCP=\$MCP\"
    fi
    sleep 1
done

echo '--- Container status ---'
sudo docker ps --filter name=gemma4-unified
echo ''
echo '--- Health check ---'
curl -sf http://localhost:3001/health 2>/dev/null || echo 'MCP not ready yet'
"

# ─── Set up GCP overrides for x86_64 ──────────────────────────
echo ""
echo "⚡ Applying GCP-optimized settings..."
gcloud compute ssh "$VM_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --tunnel-through-iap \
    --command="
cd /opt/gemma4-with-vscode

# On x86_64, we can enable flash attention and use more context
sudo docker compose --profile unified down 2>/dev/null || true

# Create GCP-specific override
sudo tee docker-compose.override.yml > /dev/null <<'OVERRIDE'
services:
  gemma4-unified:
    environment:
      - OLLAMA_FLASH_ATTENTION=true
      - OLLAMA_CONTEXT_LENGTH=8192
      - OLLAMA_LLM_LIBRARY=cpu
OVERRIDE

sudo docker compose --profile unified up -d gemma4-unified
echo 'Container restarted with GCP-optimized settings'
"

echo ""
echo "════════════════════════════════════════════════"
echo "🎉 Gemma 4 E4B deployed on GCP!"
echo ""
echo "📡 Access via IAP tunnel (run from your Mac):"
echo ""
echo "   ./scripts/gcp-deploy.sh --connect"
echo ""
echo "   This forwards:"
echo "   localhost:11434 → Ollama API"
echo "   localhost:3001  → MCP SSE"
echo ""
echo "🔧 Claude Desktop config (same as local!):"
echo '   {'
echo '     "mcpServers": {'
echo '       "gemma4-local": {'
echo '         "url": "http://localhost:3001/sse"'
echo '       }'
echo '     }'
echo '   }'
echo ""
echo "🛑 Destroy: ./scripts/gcp-deploy.sh --destroy"
echo "💰 Cost: ~\$0.27/hr (${MACHINE_TYPE})"
echo "   Stop when not in use: gcloud compute instances stop ${VM_NAME}"
echo "════════════════════════════════════════════════"
