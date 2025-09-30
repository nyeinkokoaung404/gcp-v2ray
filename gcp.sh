#!/bin/bash

# Set variables
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
SERVICE_NAME="gcp-channel-404"
UUID="ba0e3984-ccc9-48a3-8074-b2f507f41ce8"
HOST_DOMAIN="m.googleapis.com"

# Telegram Configuration
TELEGRAM_BOT_TOKEN="7736743366:AAFhGhvwu6yZRQ_txEXiAhe7LTEgzvh5Q-A"
TELEGRAM_CHANNEL_ID="-1001218917905"

echo "Enabling required APIs..."
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  iam.googleapis.com

echo "Cloning repository..."
git clone https://github.com/nyeinkokoaung404/gcp-v2ray.git
cd gcp-v2ray

echo "Building container image..."
gcloud builds submit --tag gcr.io/${PROJECT_ID}/gcp-v2ray-image

echo "Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
  --image gcr.io/${PROJECT_ID}/gcp-v2ray-image \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated# \
  #--cpu 4 \
  #--memory 16Gi \
  #--max-instances 10

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)')

# Extract domain from service URL (remove https://)
DOMAIN=$(echo $SERVICE_URL | sed 's|https://||')

# Create Trojan share link
#VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Ftg-%40nkka404&security=tls&alpn=http%2F1.1&host=${DOMAIN}&fp=randomized&type=ws&sni=${HOST_DOMAIN}#${SERVICE_NAME}"
VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Ftg-%40nkka404&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host==${DOMAIN}&fp=randomized&type=ws&sni==${DOMAIN}#${SERVICE_NAME}"

# Create the message for Telegram
MESSAGE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Cloud Run Deploy Success
Service: ${SERVICE_NAME}
Region: ${REGION}
URL: ${SERVICE_URL}

```${VLESS_LINK}```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Display locally
echo "$MESSAGE"

# Save to file
#echo "$MESSAGE" > deployment-info.txt

# Function to send message to Telegram
send_to_telegram() {
    local message="$1"
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${TELEGRAM_CHANNEL_ID}\",
            \"text\": \"$message\",
            \"disable_web_page_preview\": true
        }" \
        https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage > /dev/null
}

# Send to Telegram
echo "Sending deployment info to Telegram channel..."
if send_to_telegram "$MESSAGE"; then
    echo "✅ Successfully sent to Telegram channel: ${TELEGRAM_CHANNEL_ID}"
else
    echo "❌ Failed to send to Telegram channel"
fi

echo "Deployment completed!"
echo "Deployment info saved to deployment-info.txt"
