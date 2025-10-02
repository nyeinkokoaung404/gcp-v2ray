#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to validate UUID format
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    if [[ ! $1 =~ $uuid_pattern ]]; then
        error "Invalid UUID format: $1"
        return 1
    fi
    return 0
}

# Function to validate Telegram Bot Token
validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    if [[ ! $1 =~ $token_pattern ]]; then
        error "Invalid Telegram Bot Token format"
        return 1
    fi
    return 0
}

# Function to validate Channel ID
validate_channel_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Channel ID format"
        return 1
    fi
    return 0
}

# Function to validate Chat ID (for bot private messages)
validate_chat_id() {
    if [[ ! $1 =~ ^-?[0-9]+$ ]]; then
        error "Invalid Chat ID format"
        return 1
    fi
    return 0
}

# Function to validate domain format
validate_domain() {
    local domain_pattern='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    if [[ ! $1 =~ $domain_pattern ]]; then
        error "Invalid domain format: $1"
        return 1
    fi
    return 0
}

# Input sanitization function
sanitize_input() {
    local input="$1"
    # Remove potentially dangerous characters, allow only alphanumeric, hyphens, dots, and underscores
    echo "$input" | sed 's/[^a-zA-Z0-9._-]//g'
}

# Telegram destination selection
select_telegram_destination() {
    echo
    info "=== Telegram Notification Settings ==="
    echo "Select where to send deployment notifications:"
    echo "1. Send to Telegram Channel only"
    echo "2. Send to Bot private chat only"
    echo "3. Send to both Channel and Bot private chat"
    echo "4. Don't send to Telegram"
    
    while true; do
        read -p "Select option (1-4): " telegram_option
        case $telegram_option in
            1)
                SEND_TO_CHANNEL=true
                SEND_TO_BOT=false
                info "Will send notifications to Telegram Channel only"
                break
                ;;
            2)
                SEND_TO_CHANNEL=false
                SEND_TO_BOT=true
                info "Will send notifications to Bot private chat only"
                break
                ;;
            3)
                SEND_TO_CHANNEL=true
                SEND_TO_BOT=true
                info "Will send notifications to both Channel and Bot private chat"
                break
                ;;
            4)
                SEND_TO_CHANNEL=false
                SEND_TO_BOT=false
                info "Telegram notifications disabled"
                break
                ;;
            *)
                echo "Invalid selection. Please enter a number between 1-4."
                ;;
        esac
    done
    
    # If sending to channel or bot, get the required credentials
    if [[ "$SEND_TO_CHANNEL" == true || "$SEND_TO_BOT" == true ]]; then
        echo
        info "=== Telegram Configuration ==="
        
        # Telegram Bot Token (required for both)
        while true; do
            read -p "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if validate_bot_token "$TELEGRAM_BOT_TOKEN"; then
                break
            fi
        done
        
        # Channel ID (if sending to channel)
        if [[ "$SEND_TO_CHANNEL" == true ]]; then
            while true; do
                read -p "Enter Telegram Channel ID: " TELEGRAM_CHANNEL_ID
                if validate_channel_id "$TELEGRAM_CHANNEL_ID"; then
                    break
                fi
            done
        fi
        
        # Chat ID (if sending to bot private chat)
        if [[ "$SEND_TO_BOT" == true ]]; then
            while true; do
                read -p "Enter your Telegram Chat ID (for private messages): " TELEGRAM_CHAT_ID
                if validate_chat_id "$TELEGRAM_CHAT_ID"; then
                    break
                fi
            done
        fi
        
        # Test Telegram connectivity if requested
        if [[ "$SEND_TO_CHANNEL" == true || "$SEND_TO_BOT" == true ]]; then
            echo
            read -p "Do you want to test Telegram connectivity? (y/n): " test_tg
            if [[ $test_tg =~ [Yy] ]]; then
                test_telegram_connectivity
            fi
        fi
    fi
}

# Test Telegram connectivity
test_telegram_connectivity() {
    log "Testing Telegram connectivity..."
    local success_count=0
    
    # Test channel connectivity
    if [[ "$SEND_TO_CHANNEL" == true ]]; then
        info "Testing channel connectivity..."
        if send_to_telegram "🔍 Testing channel connectivity from deployment script..." "$TELEGRAM_CHANNEL_ID"; then
            log "✅ Channel connectivity test passed"
            ((success_count++))
        else
            error "❌ Channel connectivity test failed"
        fi
    fi
    
    # Test bot private chat connectivity
    if [[ "$SEND_TO_BOT" == true ]]; then
        info "Testing bot private chat connectivity..."
        if send_to_telegram "🔍 Testing private chat connectivity from deployment script..." "$TELEGRAM_CHAT_ID"; then
            log "✅ Bot private chat connectivity test passed"
            ((success_count++))
        else
            error "❌ Bot private chat connectivity test failed"
        fi
    fi
    
    local total_tests=$((SEND_TO_CHANNEL + SEND_TO_BOT))
    if [[ $success_count -eq $total_tests ]]; then
        log "✅ All Telegram connectivity tests passed"
    elif [[ $success_count -gt 0 ]]; then
        warn "Some Telegram connectivity tests failed, but deployment will continue"
    else
        error "All Telegram connectivity tests failed"
        read -p "Continue with deployment anyway? (y/n): " continue_deploy
        if [[ ! $continue_deploy =~ [Yy] ]]; then
            info "Deployment cancelled by user"
            exit 0
        fi
    fi
}

# Resource selection function
select_resources() {
    echo
    info "=== Resource Selection ==="
    echo "1. 1 CPU, 2GB RAM (Development) - ~$10/month"
    echo "2. 2 CPU, 4GB RAM (Production - Recommended) - ~$40/month"
    echo "3. 4 CPU, 8GB RAM (High Traffic) - ~$160/month"
    echo "4. Custom configuration"
    
    while true; do
        read -p "Select resource tier (1-4): " resource_choice
        case $resource_choice in
            1) 
                CPU="1"
                MEMORY="2Gi"
                CONTAINER_CONCURRENCY=80
                MAX_INSTANCES=10
                break 
                ;;
            2) 
                CPU="2"
                MEMORY="4Gi"
                CONTAINER_CONCURRENCY=100
                MAX_INSTANCES=20
                break 
                ;;
            3) 
                CPU="4"
                MEMORY="8Gi"
                CONTAINER_CONCURRENCY=200
                MAX_INSTANCES=50
                break 
                ;;
            4)
                select_custom_resources
                break
                ;;
            *) 
                echo "Invalid selection. Please enter a number between 1-4."
                ;;
        esac
    done
    
    info "Selected resources: $CPU CPU, $MEMORY RAM"
    info "Container Concurrency: $CONTAINER_CONCURRENCY"
    info "Max Instances: $MAX_INSTANCES"
}

# Custom resource selection
select_custom_resources() {
    echo
    info "=== Custom Resource Configuration ==="
    
    # CPU selection
    while true; do
        read -p "Enter CPU cores (1-8): " CPU
        if [[ $CPU =~ ^[1-8]$ ]]; then
            break
        else
            error "Please enter a number between 1-8"
        fi
    done
    
    # Memory selection
    while true; do
        echo "Select memory configuration:"
        echo "1. 1Gi"
        echo "2. 2Gi"
        echo "3. 4Gi"
        echo "4. 8Gi"
        echo "5. 16Gi"
        read -p "Enter choice (1-5): " mem_choice
        case $mem_choice in
            1) MEMORY="1Gi"; break ;;
            2) MEMORY="2Gi"; break ;;
            3) MEMORY="4Gi"; break ;;
            4) MEMORY="8Gi"; break ;;
            5) MEMORY="16Gi"; break ;;
            *) error "Invalid selection";;
        esac
    done
    
    # Container concurrency
    while true; do
        read -p "Enter container concurrency (10-1000) [default: 100]: " concurrency
        CONTAINER_CONCURRENCY=${concurrency:-100}
        if [[ $CONTAINER_CONCURRENCY =~ ^[0-9]+$ ]] && [ $CONTAINER_CONCURRENCY -ge 10 ] && [ $CONTAINER_CONCURRENCY -le 1000 ]; then
            break
        else
            error "Please enter a number between 10-1000"
        fi
    done
    
    # Max instances
    while true; do
        read -p "Enter maximum instances (1-100) [default: 10]: " max_inst
        MAX_INSTANCES=${max_inst:-10}
        if [[ $MAX_INSTANCES =~ ^[0-9]+$ ]] && [ $MAX_INSTANCES -ge 1 ] && [ $MAX_INSTANCES -le 100 ]; then
            break
        else
            error "Please enter a number between 1-100"
        fi
    done
}

# Cost estimation function
estimate_cost() {
    local cpu=$1
    local memory=$2
    local region=$3
    local max_instances=$4
    
    info "=== Cost Estimation ==="
    
    # Base pricing per vCPU and GB (simplified estimation)
    case $region in
        "us-central1"|"us-west1"|"us-east1")
            vcpu_hourly=0.000024
            memory_hourly=0.0000026
            ;;
        "europe-west1")
            vcpu_hourly=0.000028
            memory_hourly=0.0000030
            ;;
        "asia-southeast1"|"asia-northeast1")
            vcpu_hourly=0.000029
            memory_hourly=0.0000032
            ;;
        *)
            vcpu_hourly=0.000024
            memory_hourly=0.0000026
            ;;
    esac
    
    # Calculate memory in GB
    local memory_gb=${memory%Gi}
    
    # Calculate hourly cost per instance
    local instance_hourly=$(echo "scale=6; ($cpu * $vcpu_hourly) + ($memory_gb * $memory_hourly)" | bc)
    
    # Calculate monthly costs for different scenarios
    local monthly_light=$(echo "scale=2; $instance_hourly * 24 * 30 * 0.1" | bc)  # 10% utilization
    local monthly_medium=$(echo "scale=2; $instance_hourly * 24 * 30 * 0.5" | bc) # 50% utilization
    local monthly_heavy=$(echo "scale=2; $instance_hourly * 24 * 30 * 1.0" | bc)  # 100% utilization
    
    # Display cost estimates
    echo "┌──────────────────────────────────────┐"
    echo "│          Monthly Cost Estimate       │"
    echo "├──────────────────────────────────────┤"
    echo "│ Region: $(printf "%-25s" $region)│"
    echo "│ Configuration: $(printf "%-18s" "${cpu}CPU-${memory}")│"
    echo "├──────────────────────────────────────┤"
    echo "│ Light Usage (10%):  \$$(printf "%-15s" $monthly_light)│"
    echo "│ Medium Usage (50%): \$$(printf "%-15s" $monthly_medium)│"
    echo "│ Heavy Usage (100%): \$$(printf "%-15s" $monthly_heavy)│"
    echo "└──────────────────────────────────────┘"
    echo
    
    # Warning for high cost configurations
    if [ $(echo "$monthly_heavy > 100" | bc) -eq 1 ]; then
        warn "This configuration could cost over \$100/month at full utilization"
        warn "Consider setting up billing alerts in Google Cloud Console"
    fi
}

# Check for existing service
check_existing_service() {
    log "Checking for existing service..."
    if gcloud run services describe "$SERVICE_NAME" --region "$REGION" --quiet &>/dev/null; then
        warn "Service '$SERVICE_NAME' already exists in region '$REGION'"
        echo
        echo "Options:"
        echo "1. Replace existing service"
        echo "2. Use a different service name"
        echo "3. Cancel deployment"
        
        while true; do
            read -p "Select option (1-3): " option
            case $option in
                1)
                    info "Will replace existing service"
                    return 0
                    ;;
                2)
                    read -p "Enter new service name: " SERVICE_NAME
                    SERVICE_NAME=$(sanitize_input "$SERVICE_NAME")
                    check_existing_service  # Recursive check with new name
                    return 0
                    ;;
                3)
                    info "Deployment cancelled by user"
                    exit 0
                    ;;
                *)
                    echo "Invalid option. Please enter 1, 2, or 3."
                    ;;
            esac
        done
    fi
    return 0
}

# Health check function
health_check() {
    local service_url=$1
    local max_attempts=30
    local attempt=1
    local wait_seconds=10
    
    log "Starting health check for service..."
    info "Service URL: $service_url"
    info "Maximum attempts: $max_attempts"
    info "Wait interval: ${wait_seconds}s"
    echo
    
    while [ $attempt -le $max_attempts ]; do
        info "Health check attempt $attempt/$max_attempts..."
        
        # Try to curl the service with timeout
        if response=$(curl -s -f --max-time 30 "$service_url" 2>/dev/null); then
            log "✅ Health check PASSED - Service is responding"
            
            # Additional check for V2Ray specific endpoint if needed
            if check_v2ray_health "$service_url"; then
                log "✅ V2Ray service is healthy"
                return 0
            else
                warn "Service is responding but V2Ray health check failed"
                return 1
            fi
        else
            local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$service_url" 2>/dev/null || echo "000")
            
            if [ "$status_code" = "000" ]; then
                info "Service not ready yet (connection failed)..."
            elif [ "$status_code" = "404" ]; then
                info "Service returning 404 (may be starting)..."
            else
                info "Service returned HTTP $status_code..."
            fi
            
            # Show progress bar
            local progress=$((attempt * 100 / max_attempts))
            local bars=$((progress / 2))
            printf "Progress: [%-50s] %d%%\r" "$(printf '#%.0s' $(seq 1 $bars))" "$progress"
            
            sleep $wait_seconds
            ((attempt++))
        fi
    done
    
    error "❌ Health check FAILED - Service did not become healthy within $max_attempts attempts"
    error "Check the service logs with: gcloud run services describe $SERVICE_NAME --region $REGION"
    return 1
}

# V2Ray specific health check
check_v2ray_health() {
    local service_url=$1
    # Since V2Ray services might not expose a traditional health endpoint,
    # we'll check if the service is responding to basic requests
    if curl -s -f --max-time 30 "$service_url" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Region selection function
select_region() {
    echo
    info "=== Region Selection ==="
    echo "1. us-central1 (Iowa, USA) - Cost Effective"
    echo "2. us-west1 (Oregon, USA) - Balanced" 
    echo "3. us-east1 (South Carolina, USA) - East US"
    echo "4. europe-west1 (Belgium) - Europe"
    echo "5. asia-southeast1 (Singapore) - Southeast Asia"
    echo "6. asia-northeast1 (Tokyo, Japan) - Northeast Asia"
    echo
    
    while true; do
        read -p "Select region (1-6): " region_choice
        case $region_choice in
            1) REGION="us-central1"; break ;;
            2) REGION="us-west1"; break ;;
            3) REGION="us-east1"; break ;;
            4) REGION="europe-west1"; break ;;
            5) REGION="asia-southeast1"; break ;;
            6) REGION="asia-northeast1"; break ;;
            *) echo "Invalid selection. Please enter a number between 1-6." ;;
        esac
    done
    
    info "Selected region: $REGION"
}

# User input function
get_user_input() {
    echo
    info "=== Service Configuration ==="
    
    # Service Name
    while true; do
        read -p "Enter service name: " SERVICE_NAME
        SERVICE_NAME=$(sanitize_input "$SERVICE_NAME")
        if [[ -n "$SERVICE_NAME" ]]; then
            break
        else
            error "Service name cannot be empty"
        fi
    done
    
    # UUID
    while true; do
        read -p "Enter UUID: " UUID
        UUID=${UUID:-"ba0e3984-ccc9-48a3-8074-b2f507f41ce8"}
        if validate_uuid "$UUID"; then
            break
        fi
    done
    
    # Host Domain (optional)
    while true; do
        read -p "Enter host domain [default: m.googleapis.com]: " HOST_DOMAIN
        HOST_DOMAIN=${HOST_DOMAIN:-"m.googleapis.com"}
        if validate_domain "$HOST_DOMAIN"; then
            break
        fi
    done
}

# Display configuration summary
show_config_summary() {
    echo
    info "=== Configuration Summary ==="
    echo "Project ID:    $(gcloud config get-value project)"
    echo "Region:        $REGION"
    echo "Service Name:  $SERVICE_NAME"
    echo "Host Domain:   $HOST_DOMAIN"
    echo "UUID:          $UUID"
    
    # Telegram configuration summary
    if [[ "$SEND_TO_CHANNEL" == true || "$SEND_TO_BOT" == true ]]; then
        echo "Bot Token:     ${TELEGRAM_BOT_TOKEN:0:8}..."
        if [[ "$SEND_TO_CHANNEL" == true ]]; then
            echo "Channel ID:    $TELEGRAM_CHANNEL_ID"
        fi
        if [[ "$SEND_TO_BOT" == true ]]; then
            echo "Chat ID:       $TELEGRAM_CHAT_ID"
        fi
    else
        echo "Telegram:      Not configured"
    fi
    
    echo "Resources:     $CPU CPU, $MEMORY RAM"
    echo "Concurrency:   $CONTAINER_CONCURRENCY"
    echo "Max Instances: $MAX_INSTANCES"
    echo
    
    # Show cost estimation
    estimate_cost "$CPU" "$MEMORY" "$REGION" "$MAX_INSTANCES"
    
    while true; do
        read -p "Proceed with deployment? (y/n): " confirm
        case $confirm in
            [Yy]* ) break;;
            [Nn]* ) 
                info "Deployment cancelled by user"
                exit 0
                ;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# Validation functions
validate_prerequisites() {
    log "Validating prerequisites..."
    
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        error "git is not installed. Please install git."
        exit 1
    fi
    
    if ! command -v bc &> /dev/null; then
        error "bc (calculator) is not installed. Please install bc."
        exit 1
    fi
    
    local PROJECT_ID=$(gcloud config get-value project)
    if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
        error "No project configured. Run: gcloud config set project PROJECT_ID"
        exit 1
    fi
}

cleanup() {
    log "Cleaning up temporary files..."
    if [[ -d "gcp-v2ray" ]]; then
        rm -rf gcp-v2ray
    fi
}

# Modified send_to_telegram function to accept chat_id parameter
send_to_telegram() {
    local message="$1"
    local chat_id="$2"  # Now accepts chat_id as parameter
    local response
    
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${chat_id}\",
            \"text\": \"$message\",
            \"parse_mode\": \"MARKDOWN\",
            \"disable_web_page_preview\": true
        }" \
        https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage)
    
    local http_code="${response: -3}"
    local content="${response%???}"
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        error "❌ Failed to send to Telegram (HTTP $http_code): $content"
        return 1
    fi
}

# Function to send messages to all configured Telegram destinations
send_telegram_notifications() {
    local message="$1"
    local success_count=0
    
    # Send to channel if configured
    if [[ "$SEND_TO_CHANNEL" == true ]]; then
        info "Sending notification to Telegram channel..."
        if send_to_telegram "$message" "$TELEGRAM_CHANNEL_ID"; then
            log "✅ Successfully sent to Telegram channel"
            ((success_count++))
        else
            error "❌ Failed to send to Telegram channel"
        fi
    fi
    
    # Send to bot private chat if configured
    if [[ "$SEND_TO_BOT" == true ]]; then
        info "Sending notification to bot private chat..."
        if send_to_telegram "$message" "$TELEGRAM_CHAT_ID"; then
            log "✅ Successfully sent to bot private chat"
            ((success_count++))
        else
            error "❌ Failed to send to bot private chat"
        fi
    fi
    
    # Return success if at least one message was sent successfully
    if [[ $success_count -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Save configuration for future reference
save_config() {
    local config_file="deployment-config-${SERVICE_NAME}.conf"
    cat > "$config_file" << EOF
PROJECT_ID=$PROJECT_ID
REGION=$REGION
SERVICE_NAME=$SERVICE_NAME
UUID=$UUID
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:0:8}...
TELEGRAM_CHANNEL_ID=$TELEGRAM_CHANNEL_ID
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
SEND_TO_CHANNEL=$SEND_TO_CHANNEL
SEND_TO_BOT=$SEND_TO_BOT
HOST_DOMAIN=$HOST_DOMAIN
CPU=$CPU
MEMORY=$MEMORY
CONTAINER_CONCURRENCY=$CONTAINER_CONCURRENCY
MAX_INSTANCES=$MAX_INSTANCES
DEPLOYMENT_DATE=$(date -Iseconds)
SERVICE_URL=$SERVICE_URL
EOF
    log "Configuration saved to: $config_file"
}

main() {
    info "=== GCP Cloud Run V2Ray Deployment ==="
    
    # Initialize Telegram settings
    SEND_TO_CHANNEL=false
    SEND_TO_BOT=false
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHANNEL_ID=""
    TELEGRAM_CHAT_ID=""
    
    # Get user input
    select_region
    get_user_input
    select_telegram_destination
    select_resources
    
    PROJECT_ID=$(gcloud config get-value project)
    
    # Check for existing service
    check_existing_service
    
    show_config_summary
    
    log "Starting Cloud Run deployment..."
    log "Project: $PROJECT_ID"
    log "Region: $REGION"
    log "Service: $SERVICE_NAME"
    
    validate_prerequisites
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    log "Enabling required APIs..."
    gcloud services enable \
        cloudbuild.googleapis.com \
        run.googleapis.com \
        iam.googleapis.com \
        --quiet
    
    # Clean up any existing directory
    cleanup
    
    log "Cloning repository..."
    if ! git clone https://github.com/nyeinkokoaung404/gcp-v2ray.git; then
        error "Failed to clone repository"
        exit 1
    fi
    
    cd gcp-v2ray
    
    log "Building container image..."
    if ! gcloud builds submit --tag gcr.io/${PROJECT_ID}/gcp-v2ray-image --quiet; then
        error "Build failed"
        exit 1
    fi
    
    log "Deploying to Cloud Run..."
    if ! gcloud run deploy ${SERVICE_NAME} \
        --image gcr.io/${PROJECT_ID}/gcp-v2ray-image \
        --platform managed \
        --region ${REGION} \
        --allow-unauthenticated \
        --cpu ${CPU} \
        --memory ${MEMORY} \
        --concurrency ${CONTAINER_CONCURRENCY} \
        --max-instances ${MAX_INSTANCES} \
        --quiet; then
        error "Deployment failed"
        exit 1
    fi
    
    # Get the service URL
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
        --region ${REGION} \
        --format 'value(status.url)' \
        --quiet)
    
    DOMAIN=$(echo $SERVICE_URL | sed 's|https://||')
    
    # Perform health check
    log "Starting post-deployment health checks..."
    if health_check "$SERVICE_URL"; then
        log "✅ All health checks passed"
        HEALTH_STATUS="✅ Passed"
    else
        warn "Health checks reported issues, but deployment completed"
        warn "Service might need more time to become fully operational"
        HEALTH_STATUS="⚠️  Issues detected"
    fi
    
    # Create Vless share link
    VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Ftg-%40nkka404&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${SERVICE_NAME}"
    
    # Create message
    MESSAGE="━━━━━━━━━━━━━━━━━━━━
*Cloud Run Deploy Success* ✅
*Project:* \`${PROJECT_ID}\`
*Service:* \`${SERVICE_NAME}\`
*Region:* \`${REGION}\`
*Resources:* \`${CPU} CPU, ${MEMORY} RAM\`
*URL:* \`${SERVICE_URL}\`
*Health Check:* ${HEALTH_STATUS}

\`\`\`
${VLESS_LINK}
\`\`\`
*Usage:* Copy the above link and import to your V2Ray client
━━━━━━━━━━━━━━━━━━━━"
    
    # Save to file
    echo "$MESSAGE" > deployment-info.txt
    log "Deployment info saved to deployment-info.txt"
    
    # Save configuration
    save_config
    
    # Display locally
    echo
    info "=== Deployment Information ==="
    echo "$MESSAGE"
    echo
    
    # Send to Telegram if configured
    if [[ "$SEND_TO_CHANNEL" == true || "$SEND_TO_BOT" == true ]]; then
        log "Sending deployment info to Telegram..."
        if send_telegram_notifications "$MESSAGE"; then
            log "✅ Message sent successfully to all configured Telegram destinations"
        else
            warn "Message failed to send to some Telegram destinations, but deployment was successful"
        fi
    else
        info "Telegram notifications not configured"
    fi
    
    log "Deployment completed successfully!"
    log "Service URL: $SERVICE_URL"
    log "Configuration saved to: deployment-config-${SERVICE_NAME}.conf"
    log "Health check: $HEALTH_STATUS"
    
    # Display useful commands
    echo
    info "=== Useful Commands ==="
    echo "View logs:          gcloud run logs read $SERVICE_NAME --region $REGION"
    echo "Service details:    gcloud run services describe $SERVICE_NAME --region $REGION"
    echo "Monitor costs:      gcloud billing accounts list"
    echo "Delete service:     gcloud run services delete $SERVICE_NAME --region $REGION"
}

# Run main function
main "$@"
