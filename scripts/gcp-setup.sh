#!/bin/bash
# ─────────────────────────────────────────────────────────────
# gcp-setup.sh — One-time GCP setup for Gemma 4 Cloud Build
#
# Run this ONCE before your first Cloud Build trigger fires.
# Creates: Artifact Registry repo, IAP firewall, enables APIs.
#
# Usage:
#   export GCP_PROJECT_ID=your-project-id
#   ./scripts/gcp-setup.sh
# ─────────────────────────────────────────────────────────────
set -e

PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${GCP_REGION:-us-central1}"
REPO_NAME="${GCP_ARTIFACT_REPO:-gemma4-repo}"

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Set GCP_PROJECT_ID or run: gcloud config set project YOUR_PROJECT"
    exit 1
fi

echo "════════════════════════════════════════════════"
echo "  Gemma 4 — GCP One-Time Setup"
echo "  Project: ${PROJECT_ID}"
echo "  Region:  ${REGION}"
echo "════════════════════════════════════════════════"

# Enable required APIs
echo ""
echo "1️⃣  Enabling APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    compute.googleapis.com \
    iap.googleapis.com \
    --project="$PROJECT_ID"
echo "   ✅ APIs enabled"

# Create Artifact Registry repo
echo ""
echo "2️⃣  Creating Artifact Registry repo: ${REPO_NAME}..."
if gcloud artifacts repositories describe "$REPO_NAME" \
    --project="$PROJECT_ID" --location="$REGION" &>/dev/null; then
    echo "   ✅ Already exists"
else
    gcloud artifacts repositories create "$REPO_NAME" \
        --project="$PROJECT_ID" \
        --location="$REGION" \
        --repository-format=docker \
        --description="Gemma 4 E4B unified Docker images"
    echo "   ✅ Created"
fi

# IAP firewall rule
echo ""
echo "3️⃣  Creating IAP firewall rule..."
if gcloud compute firewall-rules describe allow-iap-gemma4 \
    --project="$PROJECT_ID" &>/dev/null; then
    echo "   ✅ Already exists"
else
    gcloud compute firewall-rules create allow-iap-gemma4 \
        --project="$PROJECT_ID" \
        --direction=INGRESS \
        --action=ALLOW \
        --rules=tcp:22 \
        --source-ranges="35.235.240.0/20" \
        --target-tags="gemma4-iap" \
        --description="Allow IAP SSH tunnel for Gemma 4 VM"
    echo "   ✅ Created"
fi

# Grant Cloud Build permissions
echo ""
echo "4️⃣  Granting Cloud Build service account permissions..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Compute admin (to SSH into VMs for deploy step)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/compute.instanceAdmin.v1" \
    --condition=None --quiet 2>/dev/null

# IAP tunnel user (to SSH via IAP)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/iap.tunnelResourceAccessor" \
    --condition=None --quiet 2>/dev/null

# Service account user (to act as compute SA)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/iam.serviceAccountUser" \
    --condition=None --quiet 2>/dev/null

echo "   ✅ Cloud Build SA permissions set"

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo ""
echo "  1. Create Cloud Build trigger:"
echo "     gcloud builds triggers create github \\"
echo "       --repo-name=gemma4-with-vscode \\"
echo "       --repo-owner=YOUR_GITHUB_USER \\"
echo "       --branch-pattern='^main$' \\"
echo "       --build-config=cloudbuild.yaml \\"
echo "       --project=${PROJECT_ID}"
echo ""
echo "  2. Or build manually:"
echo "     cd gemma4-with-vscode"
echo "     gcloud builds submit --config=cloudbuild.yaml . --project=${PROJECT_ID}"
echo ""
echo "  3. Create the VM (if not done):"
echo "     ./scripts/gcp-deploy.sh"
echo ""
echo "  4. Connect:"
echo "     ./scripts/gcp-deploy.sh --connect"
echo "════════════════════════════════════════════════"
