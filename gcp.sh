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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration with user input
echo "🚀 GCP Cloud Run V2Ray Deployment Script"
echo "=========================================="

# Get user inputs
read -p "Enter your Service Name (e.g., gcp-channel-404): " SERVICE_NAME
read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
read -p "Enter your Telegram Channel ID: " TELEGRAM_CHANNEL_ID

# UUID for V2Ray configuration
UUID="ba0e3984-ccc9-48a3-8074-b2f507f41ce8"
HOST_DOMAIN="m.googleapis.com"
PROJECT_ID=$(gcloud config get-value project)

# Region selection menu
echo ""
echo "Select Region:"
echo "1. us-central1 (Iowa)"
echo "2. us-east1 (South Carolina)"
echo "3. us-west1 (Oregon)"
echo "4. europe-west1 (Belgium)"
echo "5. asia-southeast1 (Singapore)"
echo "6. asia-northeast1 (Tokyo)"
read -p "Enter your choice (1-6): " REGION_CHOICE

case $REGION_CHOICE in
    1) REGION="us-central1" ;;
    2) REGION="us-east1" ;;
    3) REGION="us-west1" ;;
    4) REGION="europe-west1" ;;
    5) REGION="asia-southeast1" ;;
    6) REGION="asia-northeast1" ;;
    *) 
        print_error "Invalid region choice. Using default: us-central1"
        REGION="us-central1"
        ;;
esac

print_status "Selected Region: $REGION"
print_status "Service Name: $SERVICE_NAME"
print_status "Project ID: $PROJECT_ID"

echo ""
print_status "Starting deployment process..."

# Enable required APIs
print_status "Enabling required Google Cloud APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    iam.googleapis.com

# Clone repository
print_status "Cloning V2Ray repository..."
if [[ ! -d "gcp-v2ray" ]]; then
    git clone https://github.com/nyeinkokoaung404/gcp-v2ray.git
else
    print_warning "Repository already exists, pulling latest changes..."
    cd gcp-v2ray && git pull && cd ..
fi

cd gcp-v2ray

# Build container image
print_status "Building container image..."
gcloud builds submit --tag "gcr.io/${PROJECT_ID}/gcp-v2ray-image"

# Deploy to Cloud Run
print_status "Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "gcr.io/${PROJECT_ID}/gcp-v2ray-image" \
    --platform managed \
    --region "${REGION}" \
    --allow-unauthenticated \
    --cpu 2 \
    --memory 4Gi \
    --max-instances 5

# Get service URL
print_status "Getting service URL..."
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --region "${REGION}" \
    --format 'value(status.url)')
DOMAIN=$(echo "$SERVICE_URL" | sed 's|https://||')

print_status "Service deployed successfully: $SERVICE_URL"

# Generate Vless link
VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Ftg-%40nkka404&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${SERVICE_NAME}"

# Create message with MARKDOWN format
read -r -d '' MESSAGE << EOM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ *Cloud Run Deploy Success*

*Service:* \`${SERVICE_NAME}\`
*Region:* \`${REGION}\`
*Project:* \`${PROJECT_ID}\`
*URL:* \`${SERVICE_URL}\`

*Vless Configuration:*
\`\`\`
${VLESS_LINK}
\`\`\`

*Usage:* Copy the above link and import to your V2Ray client
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOM

# Display locally
echo ""
print_status "Deployment Information:"
echo "$MESSAGE"

# Save to file
echo "$MESSAGE" > "deployment-info-${SERVICE_NAME}.txt"
print_status "Deployment info saved to: deployment-info-${SERVICE_NAME}.txt"

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

# Send to Telegram
print_status "Sending deployment info to Telegram..."
if send_telegram_message "$MESSAGE"; then
    print_status "✅ Successfully sent to Telegram channel: ${TELEGRAM_CHANNEL_ID}"
else
    print_error "❌ Failed to send to Telegram channel"
    print_warning "Please check your bot token and channel ID"
fi

# Display final information
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_status "🎉 Deployment Completed Successfully!"
echo ""
print_status "📋 Service Details:"
echo "   - Service Name: $SERVICE_NAME"
echo "   - Region: $REGION"
echo "   - URL: $SERVICE_URL"
echo "   - Project: $PROJECT_ID"
echo ""
print_status "📁 Deployment info saved to: deployment-info-${SERVICE_NAME}.txt"
print_status "📢 Notification sent to Telegram channel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test the service
echo ""
read -p "Do you want to test the service? (y/n): " TEST_CHOICE
if [[ $TEST_CHOICE == "y" || $TEST_CHOICE == "Y" ]]; then
    print_status "Testing service endpoint..."
    if curl -s --head --fail "$SERVICE_URL" > /dev/null; then
        print_status "✅ Service is responding correctly"
    else
        print_warning "⚠️  Service might be having issues"
    fi
fi

echo ""
print_status "Script execution completed!"
