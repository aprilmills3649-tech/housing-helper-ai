#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
PROJECT_ID="${GCP_PROJECT_ID:-$(gcloud config get-value project)}"
REGION="${GCP_REGION:-us-east1}"
REPO_NAME="housing-helper-repo"
SERVICE_NAME="housing-helper-ai"
IMAGE_TAG="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$SERVICE_NAME:latest"

echo "============================================="
echo " Deploying Housing Helper AI to Cloud Run"
echo " Project: $PROJECT_ID | Region: $REGION"
echo "============================================="

# 1. Verify project selection
if [ -z "$PROJECT_ID" ]; then
  echo "Error: No Google Cloud Project ID found. Run 'gcloud config set project YOUR_PROJECT_ID'."
  exit 1
fi

# 2. Enable necessary Google Cloud APIs
echo "--> Enabling required APIs..."
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com

# 3. Create Artifact Registry repository if it doesn't already exist
if ! gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" &>/dev/null; then
  echo "--> Creating Artifact Registry repository..."
  gcloud artifacts repositories create "$REPO_NAME" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository for Housing Helper AI"
fi

# 4. Store GEMINI_API_KEY securely in Secret Manager (if not present)
if [ -n "${GEMINI_API_KEY:-}" ]; then
  if ! gcloud secrets describe gemini-api-key &>/dev/null; then
    echo "--> Creating secret in Secret Manager..."
    echo -n "$GEMINI_API_KEY" | gcloud secrets create gemini-api-key --data-file=-
  else
    echo "--> Updating existing secret in Secret Manager..."
    echo -n "$GEMINI_API_KEY" | gcloud secrets versions add gemini-api-key --data-file=-
  fi
fi

# 5. Build and push container using Google Cloud Build
echo "--> Building container image with Cloud Build..."
gcloud builds submit --tag "$IMAGE_TAG" .

# 6. Deploy to Google Cloud Run
echo "--> Deploying service to Cloud Run..."
if gcloud secrets describe gemini-api-key &>/dev/null; then
  # Secure deployment referencing Secret Manager
  gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_TAG" \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-secrets="GEMINI_API_KEY=gemini-api-key:latest"
else
  # Fallback to direct env var if Secret Manager was not configured
  gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_TAG" \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-env-vars="GEMINI_API_KEY=${GEMINI_API_KEY:-}"
fi

echo "============================================="
echo " Deployment Complete!"
echo " Service URL: $(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')"
echo "============================================="