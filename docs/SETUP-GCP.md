# Gemma 4 E4B — GCP Deployment Guide

## Architecture

```
Your Mac                          GCP VM (e2-standard-8)
┌──────────────┐    IAP Tunnel    ┌─────────────────────────────┐
│ Claude       │ ── :3001 ──────► │ ┌─────────────────────────┐ │
│ Desktop      │                  │ │   Unified Container     │ │
│              │ ── :11434 ─────► │ │                         │ │
│ VS Code      │                  │ │  Ollama (:11434)        │ │
│ (Continue)   │                  │ │  + MCP SSE (:3001)      │ │
│              │                  │ │  + gemma4:e4b model     │ │
│ curl/Python  │                  │ └─────────────────────────┘ │
└──────────────┘                  │  No external IP             │
                                  │  IAP-only access            │
                                  └─────────────────────────────┘
```

## Quick Start

### 1. Deploy (one command)

```bash
# Set your project
export GCP_PROJECT_ID=your-project-id

# Deploy — creates VM, installs Docker, builds image, starts container
./scripts/gcp-deploy.sh
```

### 2. Connect (IAP tunnel)

```bash
# Opens secure tunnel — ports appear as localhost on your Mac
./scripts/gcp-deploy.sh --connect
```

Keep this running in a terminal tab. While connected:
- `http://localhost:11434` → Ollama API
- `http://localhost:3001/sse` → MCP SSE endpoint
- `http://localhost:3001/health` → Health check

### 3. Configure Claude Desktop

Same config as local — the IAP tunnel makes it appear as localhost:

```json
{
  "mcpServers": {
    "gemma4-local": {
      "url": "http://localhost:3001/sse"
    }
  }
}
```

### 4. Test

```bash
# Health check
curl http://localhost:3001/health

# Chat
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"gemma4:e4b","messages":[{"role":"user","content":"Hello from GCP!"}]}'
```

## VM Specs

| Setting | Value | Why |
|---------|-------|-----|
| Machine type | e2-standard-8 | 8 vCPU, 32 GB RAM — enough for Gemma 4 E4B with headroom |
| Disk | 50 GB SSD | Model is ~10 GB + Docker images + OS |
| OS | Ubuntu 22.04 LTS | Stable Docker support |
| External IP | None | Security — access only via IAP tunnel |
| Firewall | IAP range only (35.235.240.0/20) | Google's IAP proxy IP range on port 22 |

## GCP-Optimized Settings

On x86_64 GCP VMs (vs ARM64 Mac Docker), these are enabled automatically:

| Setting | Mac Docker | GCP VM | Why |
|---------|-----------|--------|-----|
| `OLLAMA_FLASH_ATTENTION` | `false` | `true` | Safe on x86_64, crashes on ARM64 Docker |
| `OLLAMA_CONTEXT_LENGTH` | `4096` | `8192` | GCP has more RAM |
| `OLLAMA_LLM_LIBRARY` | `cpu` | `cpu` | No GPU on e2 instances |

## Cost Management

```bash
# Stop VM when not in use (keeps disk, stops billing for CPU)
gcloud compute instances stop gemma4-vm --zone=us-central1-a

# Start when needed
gcloud compute instances start gemma4-vm --zone=us-central1-a

# Delete everything
./scripts/gcp-deploy.sh --destroy
```

**Estimated cost**: ~$0.27/hr ($194/mo if running 24/7). Stop when not in use.

## Customization

Override defaults via environment variables before running gcp-deploy.sh:

```bash
export GCP_PROJECT_ID=my-project
export GCP_ZONE=us-west1-b
export GCP_VM_NAME=gemma4-dev
export GCP_MACHINE_TYPE=e2-standard-16    # More RAM for larger context
export GCP_DISK_SIZE=100                   # Bigger disk for multiple models
./scripts/gcp-deploy.sh
```

## Troubleshooting

```bash
# SSH into VM
gcloud compute ssh gemma4-vm --zone=us-central1-a --tunnel-through-iap

# Check container logs
sudo docker logs gemma4-unified --tail 50

# Check startup script logs
sudo cat /var/log/gemma4-startup.log

# Restart container
cd /opt/gemma4-with-vscode
sudo docker compose --profile unified restart
```
