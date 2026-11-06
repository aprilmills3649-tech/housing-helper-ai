# 1. Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_GCP_PROJECT_ID

# 2. Build and submit container image via Google Cloud Build
gcloud builds submit --tag gcr.io/YOUR_GCP_PROJECT_ID/housing-helper-ai

# 3. Deploy container service to Cloud Run with server-side GEMINI_API_KEY
gcloud run deploy housing-helper-ai \
  --image gcr.io/YOUR_GCP_PROJECT_ID/housing-helper-ai \
  --platform managed \
  --region us-east1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY="AIzaSyYourSecretKeyHere"