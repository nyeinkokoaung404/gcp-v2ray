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

# Function to validate CPU input
validate_cpu() {
    local cpu=$1
    if [[ $cpu =~ ^[1-4]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate memory input
validate_memory() {
    local memory=$1
    if [[ $memory =~ ^[1-8]Gi$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate instances input
validate_instances() {
    local instances=$1
    if [[ $instances =~ ^[1-9][0-9]*$ ]] && [ $instances -le 100 ]; then
        return 0
    else
        return 1
    fi
}

# Function to validate concurrency input
validate_concurrency() {
    local concurrency=$1
    if [[ $concurrency =~ ^[1-9][0-9]*$ ]] && [ $concurrency -le 1000 ]; then
        return 0
    else
        return 1
    fi
}

# Function to calculate estimated cost
calculate_cost() {
    local cpu=$1
    local memory=$2
    local max_instances=$3
    
    # GCP Cloud Run pricing (as of 2024)
    local CPU_PRICE=0.00002400  # per vCPU-second
    local MEMORY_PRICE=0.00000250  # per GiB-second
    local REQUESTS_PRICE=0.40  # per million requests
    
    # Calculate hourly costs for 1 instance running full hour
    local cpu_hourly=$(echo "$cpu * $CPU_PRICE * 3600" | bc -l)
    local memory_hourly=$(echo "${memory%Gi} * $MEMORY_PRICE * 3600" | bc -l)
    local total_hourly=$(echo "$cpu_hourly + $memory_hourly" | bc -l)
    
    # Calculate monthly cost (assuming 730 hours)
    local monthly_cost=$(echo "$total_hourly * 730 * $max_instances" | bc -l)
    
    echo "$monthly_cost"
}

# Function to recommend resources based on usage
recommend_resources() {
    echo ""
    print_status "💡 Resource Recommendation Guide:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Personal Use (1-3 users):"
    echo "   - CPU: 1, Memory: 1Gi, Instances: 2"
    echo "   - Estimated: ~$10-15/month"
    echo ""
    echo "2. Small Team (5-10 users):"
    echo "   - CPU: 2, Memory: 2Gi, Instances: 3"
    echo "   - Estimated: ~$25-35/month"
    echo ""
    echo "3. Medium Team (10-20 users):"
    echo "   - CPU: 2, Memory: 4Gi, Instances: 5"
    echo "   - Estimated: ~$40-60/month"
    echo ""
    echo "4. Large Usage (20+ users):"
    echo "   - CPU: 4, Memory: 8Gi, Instances: 10"
    echo "   - Estimated: ~$100-150/month"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Function to optimize resource configuration
optimize_resources() {
    echo ""
    print_status "🔄 Resource Optimization Configuration"
    echo "=========================================="
    
    # Display recommendations
    recommend_resources
    
    # CPU Configuration
    while true; do
        read -p "Enter CPU allocation (1-4, default: 2): " CPU_INPUT
        CPU=${CPU_INPUT:-2}
        if validate_cpu $CPU; then
            break
        else
            print_error "Invalid CPU value. Please enter 1, 2, 3, or 4"
        fi
    done
    
    # Memory Configuration
    while true; do
        read -p "Enter Memory allocation (1Gi-8Gi, default: 4Gi): " MEMORY_INPUT
        MEMORY=${MEMORY_INPUT:-"4Gi"}
        if validate_memory $MEMORY; then
            break
        else
            print_error "Invalid memory format. Use format like 2Gi, 4Gi, 8Gi"
        fi
    done
    
    # Max Instances
    while true; do
        read -p "Enter Max Instances (1-100, default: 5): " INSTANCES_INPUT
        MAX_INSTANCES=${INSTANCES_INPUT:-5}
        if validate_instances $MAX_INSTANCES; then
            break
        else
            print_error "Invalid instances number. Please enter between 1-100"
        fi
    done
    
    # Concurrency (optional advanced setting)
    read -p "Enter Request Concurrency (1-1000, default: 80): " CONCURRENCY_INPUT
    CONCURRENCY=${CONCURRENCY_INPUT:-80}
    if ! validate_concurrency $CONCURRENCY; then
        print_warning "Invalid concurrency, using default: 80"
        CONCURRENCY=80
    fi
    
    # Calculate estimated cost
    ESTIMATED_COST=$(calculate_cost $CPU $MEMORY $MAX_INSTANCES)
    
    # Display configuration summary
    echo ""
    print_status "📊 Resource Configuration Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CPU: $CPU vCPU"
    echo "Memory: $MEMORY"
    echo "Max Instances: $MAX_INSTANCES"
    echo "Concurrency: $CONCURRENCY requests/instance"
    echo "Estimated Monthly Cost: ~$$(printf "%.2f" $ESTIMATED_COST)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Confirm configuration
    read -p "Confirm this configuration? (y/n): " CONFIRM
    if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
        print_status "Restarting resource configuration..."
        optimize_resources
    fi
}

# Function to check current resource usage
check_current_usage() {
    if gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" &>/dev/null; then
        print_status "📈 Checking current service usage..."
        
        # Get service CPU and memory
        CURRENT_CPU=$(gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format="value(spec.template.containers[0].resources.limits.cpu)" 2>/dev/null || echo "Unknown")
        CURRENT_MEMORY=$(gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format="value(spec.template.containers[0].resources.limits.memory)" 2>/dev/null || echo "Unknown")
        
        if [[ $CURRENT_CPU != "Unknown" ]]; then
            echo "Current CPU: $CURRENT_CPU"
            echo "Current Memory: $CURRENT_MEMORY"
        fi
    fi
}

# Function to auto-scale based on time of day
setup_auto_scaling() {
    echo ""
    read -p "Enable time-based auto-scaling? (y/n): " AUTO_SCALE_ENABLE
    
    if [[ $AUTO_SCALE_ENABLE == "y" || $AUTO_SCALE_ENABLE == "Y" ]]; then
        print_status "⏰ Setting up time-based auto-scaling..."
        
        # Default scaling profiles
        DAYTIME_MAX_INSTANCES=$((MAX_INSTANCES > 8 ? MAX_INSTANCES : 8))
        NIGHTTIME_MAX_INSTANCES=$((MAX_INSTANCES / 2 > 2 ? MAX_INSTANCES / 2 : 2))
        
        echo "Daytime (8:00-22:00): Max $DAYTIME_MAX_INSTANCES instances"
        echo "Nighttime (22:00-8:00): Max $NIGHTTIME_MAX_INSTANCES instances"
        
        # This would typically be implemented with Cloud Scheduler
        print_warning "Auto-scaling configuration saved. Manual setup required for Cloud Scheduler."
    fi
}

# Function to optimize for cost
optimize_for_cost() {
    echo ""
    print_status "💰 Cost Optimization Mode"
    CPU=1
    MEMORY="2Gi"
    MAX_INSTANCES=2
    CONCURRENCY=50
    
    ESTIMATED_COST=$(calculate_cost $CPU $MEMORY $MAX_INSTANCES)
    
    echo "Cost-optimized configuration:"
    echo "CPU: $CPU vCPU | Memory: $MEMORY"
    echo "Max Instances: $MAX_INSTANCES | Concurrency: $CONCURRENCY"
    echo "Estimated Monthly Cost: ~$$(printf "%.2f" $ESTIMATED_COST)"
    
    read -p "Use this cost-optimized configuration? (y/n): " USE_COST_OPTIMIZED
    if [[ $USE_COST_OPTIMIZED == "y" || $USE_COST_OPTIMIZED == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to optimize for performance
optimize_for_performance() {
    echo ""
    print_status "🚀 Performance Optimization Mode"
    CPU=4
    MEMORY="8Gi"
    MAX_INSTANCES=10
    CONCURRENCY=100
    
    ESTIMATED_COST=$(calculate_cost $CPU $MEMORY $MAX_INSTANCES)
    
    echo "Performance-optimized configuration:"
    echo "CPU: $CPU vCPU | Memory: $MEMORY"
    echo "Max Instances: $MAX_INSTANCES | Concurrency: $CONCURRENCY"
    echo "Estimated Monthly Cost: ~$$(printf "%.2f" $ESTIMATED_COST)"
    
    read -p "Use this performance-optimized configuration? (y/n): " USE_PERF_OPTIMIZED
    if [[ $USE_PERF_OPTIMIZED == "y" || $USE_PERF_OPTIMIZED == "Y" ]]; then
        return 0
    else
        return 1
    fi
}

# Main resource optimization function
setup_resource_optimization() {
    echo ""
    print_status "🎯 Resource Optimization Setup"
    echo "=========================================="
    
    # Check if service already exists
    check_current_usage
    
    # Optimization mode selection
    echo ""
    echo "Select Optimization Mode:"
    echo "1. Custom Configuration"
    echo "2. Cost Optimized (Budget-friendly)"
    echo "3. Performance Optimized (High-performance)"
    echo "4. Balanced (Recommended)"
    read -p "Enter your choice (1-4): " OPT_MODE_CHOICE
    
    case $OPT_MODE_CHOICE in
        1)
            print_status "Using custom configuration..."
            optimize_resources
            ;;
        2)
            if optimize_for_cost; then
                print_status "Cost-optimized configuration selected"
            else
                optimize_resources
            fi
            ;;
        3)
            if optimize_for_performance; then
                print_status "Performance-optimized configuration selected"
            else
                optimize_resources
            fi
            ;;
        4)
            # Balanced configuration
            CPU=2
            MEMORY="4Gi"
            MAX_INSTANCES=5
            CONCURRENCY=80
            ESTIMATED_COST=$(calculate_cost $CPU $MEMORY $MAX_INSTANCES)
            
            print_status "Using balanced configuration:"
            echo "CPU: $CPU | Memory: $MEMORY | Instances: $MAX_INSTANCES"
            echo "Estimated Monthly Cost: ~$$(printf "%.2f" $ESTIMATED_COST)"
            ;;
        *)
            print_warning "Invalid choice, using balanced configuration"
            CPU=2
            MEMORY="4Gi"
            MAX_INSTANCES=5
            CONCURRENCY=80
            ;;
    esac
    
    # Setup auto-scaling if desired
    setup_auto_scaling
}

# Function to escape special characters for Telegram
escape_telegram_text() {
    local text="$1"
    # Escape characters that have special meaning in Telegram Markdown
    text="${text//\*/\\*}"
    text="${text//_/\\_}"
    text="${text//\[/\\[}"
    text="${text//\]/\\]}"
    text="${text//\(/\\(}"
    text="${text//\)/\\)}"
    text="${text//\~/\\~}"
    text="${text//\`/\\\`}"
    text="${text//>/\\>}"
    text="${text//#/\\#}"
    text="${text//+/\\+}"
    text="${text//-/\\-}"
    text="${text//=/\\=}"
    text="${text//|/\\|}"
    text="${text//\{/\\{}"
    text="${text//\}/\\}}"
    text="${text//\./\\\.}"
    text="${text//\!/\\!}"
    echo "$text"
}

# Telegram notification function with proper formatting
send_telegram_message() {
    local text="$1"
    local escaped_text=$(escape_telegram_text "$text")
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${TELEGRAM_CHANNEL_ID}\",
            \"text\": \"$escaped_text\",
            \"disable_web_page_preview\": true,
            \"parse_mode\": \"MarkdownV2\"
        }" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" > /dev/null 2>&1
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
echo "1. us-central1 (Iowa) - Cost Effective"
echo "2. us-east1 (South Carolina) - Balanced"
echo "3. us-west1 (Oregon) - Balanced"
echo "4. europe-west1 (Belgium) - EU Users"
echo "5. asia-southeast1 (Singapore) - Asia Users"
echo "6. asia-northeast1 (Tokyo) - Asia Users"
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

# Setup resource optimization
setup_resource_optimization

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

# Deploy to Cloud Run with optimized resources
print_status "Deploying to Cloud Run with optimized configuration..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "gcr.io/${PROJECT_ID}/gcp-v2ray-image" \
    --platform managed \
    --region "${REGION}" \
    --allow-unauthenticated \
    --cpu "${CPU}" \
    --memory "${MEMORY}" \
    --max-instances "${MAX_INSTANCES}" \
    --concurrency "${CONCURRENCY}"

# Get service URL
print_status "Getting service URL..."
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --region "${REGION}" \
    --format 'value(status.url)')
DOMAIN=$(echo "$SERVICE_URL" | sed 's|https://||')

print_status "Service deployed successfully: $SERVICE_URL"

# Generate Vless link
VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Ftg-%40nkka404&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${SERVICE_NAME}"

# Create message for Telegram (without code blocks for vless link)
read -r -d '' TELEGRAM_MESSAGE << EOM
✅ *Cloud Run Deploy Success*

*Service:* ${SERVICE_NAME}
*Region:* ${REGION}
*Project:* ${PROJECT_ID}
*URL:* ${SERVICE_URL}

*Resource Configuration:*
- CPU: ${CPU} vCPU
- Memory: ${MEMORY}
- Max Instances: ${MAX_INSTANCES}
- Concurrency: ${CONCURRENCY}

*Vless Configuration:*
${VLESS_LINK}

*Usage:* Copy the above link and import to your V2Ray client
EOM

# Create message for local console (with better formatting)
read -r -d '' CONSOLE_MESSAGE << EOM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Cloud Run Deploy Success

Service: ${SERVICE_NAME}
Region: ${REGION}
Project: ${PROJECT_ID}
URL: ${SERVICE_URL}

Resource Configuration:
- CPU: ${CPU} vCPU
- Memory: ${MEMORY}
- Max Instances: ${MAX_INSTANCES}
- Concurrency: ${CONCURRENCY}

Vless Configuration:
${VLESS_LINK}

Usage: Copy the above link and import to your V2Ray client
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOM

# Display locally
echo ""
print_status "Deployment Information:"
echo "$CONSOLE_MESSAGE"

# Save to file
echo "$CONSOLE_MESSAGE" > "deployment-info-${SERVICE_NAME}.txt"
print_status "Deployment info saved to: deployment-info-${SERVICE_NAME}.txt"

# Send to Telegram
print_status "Sending deployment info to Telegram..."
if send_telegram_message "$TELEGRAM_MESSAGE"; then
    print_status "✅ Successfully sent to Telegram channel: ${TELEGRAM_CHANNEL_ID}"
else
    print_error "❌ Failed to send to Telegram channel"
    print_warning "Please check your bot token and channel ID"
    
    # Show the actual message that would be sent for debugging
    echo ""
    print_warning "Message that was attempted to send:"
    echo "----------------------------------------"
    echo "$TELEGRAM_MESSAGE"
    echo "----------------------------------------"
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
print_status "⚙️ Resource Configuration:"
echo "   - CPU: $CPU vCPU"
echo "   - Memory: $MEMORY"
echo "   - Max Instances: $MAX_INSTANCES"
echo "   - Concurrency: $CONCURRENCY"
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
