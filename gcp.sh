#!/bin/bash

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Region selection
print_step "Select Region for Deployment:"
echo "1. us-central1"
echo "2. us-east1" 
echo "3. europe-west1"
echo "4. asia-southeast1"
echo "5. asia-east1"
read -p "Enter your choice (1-5): " region_choice

case $region_choice in
    1) REGION="us-central1" ;;
    2) REGION="us-east1" ;;
    3) REGION="europe-west1" ;;
    4) REGION="asia-southeast1" ;;
    5) REGION="asia-east1" ;;
    *) 
        print_error "Invalid selection. Using default region: us-central1"
        REGION="us-central1"
        ;;
esac

print_status "Selected Region: $REGION"

# User input for configuration
print_step "Please enter the following configuration:"
read -p "Service Name: " SERVICE_NAME
read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
read -p "Telegram Channel ID: " TELEGRAM_CHANNEL_ID

# Validate inputs
if [[ -z "$SERVICE_NAME" || -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHANNEL_ID" ]]; then
    print_error "All fields are required!"
    exit 1
fi

# Fixed UUID and domain
UUID="ba0e3984-ccc9-48a3-8074-b2f507f41ce8"
HOST_DOMAIN="m.googleapis.com"
PROJECT_ID=$(gcloud config get-value project)

print_step "Starting deployment with configuration:"
echo "Project: $PROJECT_ID"
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"

# Enable APIs
print_step "Enabling required APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    iam.googleapis.com

# Clone repository
print_step "Cloning repository..."
if [[ ! -d "gcp-v2ray" ]]; then
    git clone https://github.com/nyeinkokoaung404/gcp-v2ray.git
fi
cd gcp-v2ray

# Build container
print_step "Building container image..."
gcloud builds submit --tag "gcr.io/${PROJECT_ID}/gcp-v2ray-image"

# Deploy to Cloud Run
print_step "Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "gcr.io/${PROJECT_ID}/gcp-v2ray-image" \
    --platform managed \
    --region "${REGION}" \
    --allow-unauthenticated \
    --cpu 2 \
    --memory 4Gi

# Get service URL
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --region "${REGION}" \
    --format 'value(status.url)')
DOMAIN=$(echo "$SERVICE_URL" | sed 's|https://||')

# Generate Vless link
VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Ftg-%40nkka404&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${SERVICE_NAME}"

# Create message with MARKDOWN formatting
read -r -d '' MESSAGE << EOM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ *Cloud Run Deploy Success*

*Service:* \`${SERVICE_NAME}\`
*Region:* \`${REGION}\`
*Project:* \`${PROJECT_ID}\`

*URL:* \`${SERVICE_URL}\`

\`\`\`
${VLESS_LINK}
\`\`\`
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOM

echo "$MESSAGE"
echo "$MESSAGE" > "deployment-info-${SERVICE_NAME}.txt"

# Telegram notification function with MARKDOWN
send_telegram_message() {
    local text="$1"
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${TELEGRAM_CHANNEL_ID}\",
            \"text\": \"$text\",
            \"disable_web_page_preview\": true,
            \"parse_mode\": \"MARKDOWN\"
        }" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
}

print_step "Sending deployment info to Telegram..."
if send_telegram_message "$MESSAGE"; then
    print_status "Successfully sent to Telegram channel: ${TELEGRAM_CHANNEL_ID}"
else
    print_error "Failed to send to Telegram channel"
    exit 1
fi

print_status "Deployment completed successfully!"
print_status "Deployment info saved to: deployment-info-${SERVICE_NAME}.txt"
print_status "Service URL: ${SERVICE_URL}"
