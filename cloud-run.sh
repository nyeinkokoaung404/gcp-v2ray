#!/usr/bin/env bash
set -euo pipefail

# ===== Ensure interactive reads even when run via curl/process substitution =====
if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
  exec </dev/tty
fi

# ===== Logging & error handler =====
LOG_FILE="/tmp/404_cloudrun_$(date +%s).log"
touch "$LOG_FILE"
on_err() {
  local rc=$?
  echo "" | tee -a "$LOG_FILE"
  echo "❌ ERROR: Command failed (exit $rc) at line $LINENO: ${BASH_COMMAND}" | tee -a "$LOG_FILE" >&2
  echo "—— LOG (last 80 lines) ——" >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  echo "📄 Log File: $LOG_FILE" >&2
  exit $rc
}
trap on_err ERR

# =================== CHANNEL 404 Custom UI ===================
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RESET=$'\e[0m'; BOLD=$'\e[1m'
  C_404=$'\e[38;5;198m'      # Channel 404 Pink
  C_ACCENT=$'\e[38;5;39m'    # Accent Blue
  C_SUCCESS=$'\e[38;5;46m'   # Success Green
  C_WARN=$'\e[38;5;214m'     # Warning Orange
  C_ERROR=$'\e[38;5;196m'    # Error Red
  C_INFO=$'\e[38;5;245m'     # Info Grey
  C_HIGHLIGHT=$'\e[38;5;226m' # Highlight Yellow
else
  RESET= BOLD= C_404= C_ACCENT= C_SUCCESS= C_WARN= C_ERROR= C_INFO= C_HIGHLIGHT=
fi

print_404_banner() {
  clear
  echo ""
  echo -e "${C_404}${BOLD}"
  echo "    ╔═══════════════════════════════════════════════════════╗"
  echo "    ║                                                       ║"
  echo "    ║  ██████╗██╗  ██╗ █████╗ ███╗   ██╗███╗   ██╗███████╗  ║"
  echo "    ║ ██╔════╝██║  ██║██╔══██╗████╗  ██║████╗  ██║██╔════╝  ║"
  echo "    ║ ██║     ███████║███████║██╔██╗ ██║██╔██╗ ██║█████╗    ║"
  echo "    ║ ██║     ██╔══██║██╔══██║██║╚██╗██║██║╚██╗██║██╔══╝    ║"
  echo "    ║ ╚██████╗██║  ██║██║  ██║██║ ╚████║██║ ╚████║███████╗  ║"
  echo "    ║  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝  ║"
  echo "    ║                                                       ║"
  echo "    ║              ${C_ACCENT}⚡ VLESS WS DEPLOYMENT SYSTEM ⚡${C_404}             ║"
  echo "    ║                                                       ║"
  echo "    ╚═══════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

print_section() {
  local title="$1"
  echo ""
  echo -e "${C_ACCENT}${BOLD}┌─────────────────────────────────────────────────────┐${RESET}"
  echo -e "${C_ACCENT}${BOLD}│${RESET} ${C_HIGHLIGHT}${BOLD}${title}${RESET}"
  echo -e "${C_ACCENT}${BOLD}└─────────────────────────────────────────────────────┘${RESET}"
}

print_step() {
  local num="$1" text="$2"
  echo -e "${C_INFO}[${C_404}STEP ${num}${C_INFO}]${RESET} ${text}"
}

print_status() {
  local type="$1" msg="$2"
  case "$type" in
    "success") echo -e "  ${C_SUCCESS}✓${RESET} ${msg}" ;;
    "info")    echo -e "  ${C_INFO}•${RESET} ${msg}" ;;
    "warning") echo -e "  ${C_WARN}⚠${RESET} ${msg}" ;;
    "error")   echo -e "  ${C_ERROR}✗${RESET} ${msg}" ;;
  esac
}

print_key_value() {
  local key="$1" value="$2"
  echo -e "  ${C_INFO}${key}:${RESET} ${C_HIGHLIGHT}${value}${RESET}"
}

print_divider() {
  echo -e "${C_INFO}───────────────────────────────────────────────────────${RESET}"
}

# Show initial banner
print_404_banner

# =================== Telegram Setup ===================
print_section "📱 TELEGRAM CONFIGURATION"
print_step "01" "Configure Telegram notifications"

TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_IDS="${TELEGRAM_CHAT_IDS:-${TELEGRAM_CHAT_ID:-}}"

if [[ ( -z "${TELEGRAM_TOKEN}" || -z "${TELEGRAM_CHAT_IDS}" ) && -f .env ]]; then
  set -a; source ./.env; set +a
  print_status "info" "Loaded configuration from .env file"
fi

if [[ -z "${TELEGRAM_TOKEN:-}" ]]; then
  echo -e -n "${C_INFO}🤖 Enter Telegram Bot Token: ${RESET}"
  read -r TELEGRAM_TOKEN || true
fi

if [[ -z "${TELEGRAM_TOKEN:-}" ]]; then
  print_status "warning" "Telegram token not provided - notifications will be skipped"
else
  print_status "success" "Telegram token configured"
fi

if [[ -z "${TELEGRAM_CHAT_IDS:-}" ]]; then
  echo -e -n "${C_INFO}👤 Enter Chat ID(s) (comma-separated): ${RESET}"
  read -r TELEGRAM_CHAT_IDS || true
fi

# =================== Custom Welcome Message ===================
print_section "💬 WELCOME MESSAGE"
print_step "02" "Customize deployment welcome message"

DEFAULT_WELCOME="🚀 Welcome to Channel 404 VLESS Service"
DEFAULT_BUTTON_LABEL="Join Channel 404"
DEFAULT_BUTTON_URL="https://t.me/premium_channel_404"

echo -e -n "${C_INFO}✏️  Welcome Message [default: ${DEFAULT_WELCOME}]: ${RESET}"
read -r CUSTOM_WELCOME || true
WELCOME_MSG="${CUSTOM_WELCOME:-$DEFAULT_WELCOME}"

BUTTON_LABELS=()
BUTTON_URLS=()

echo -e -n "${C_INFO}➕ Add URL button? [Y/n]: ${RESET}"
read -r ADD_BUTTON || true
ADD_BUTTON="${ADD_BUTTON:-Y}"

if [[ "${ADD_BUTTON^^}" == "Y" ]]; then
  echo -e -n "${C_INFO}🔖 Button Label [default: ${DEFAULT_BUTTON_LABEL}]: ${RESET}"
  read -r BUTTON_LABEL || true
  BUTTON_LABEL="${BUTTON_LABEL:-$DEFAULT_BUTTON_LABEL}"
  
  echo -e -n "${C_INFO}🔗 Button URL [default: ${DEFAULT_BUTTON_URL}]: ${RESET}"
  read -r BUTTON_URL || true
  BUTTON_URL="${BUTTON_URL:-$DEFAULT_BUTTON_URL}"
  
  BUTTON_LABELS+=("$BUTTON_LABEL")
  BUTTON_URLS+=("$BUTTON_URL")
  print_status "success" "Button added: $BUTTON_LABEL"
fi

# =================== Telegram Send Function ===================
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

send_telegram_message() {
  local text="$1"
  if [[ -z "${TELEGRAM_TOKEN:-}" || -z "${TELEGRAM_CHAT_IDS:-}" ]]; then
    return 0
  fi
  
  IFS=',' read -r -a CHAT_ID_ARR <<< "${TELEGRAM_CHAT_IDS}" || true
  
  local reply_markup=""
  if (( ${#BUTTON_LABELS[@]} > 0 )); then
    local label_escaped=$(json_escape "${BUTTON_LABELS[0]}")
    local url_escaped=$(json_escape "${BUTTON_URLS[0]}")
    reply_markup="{\"inline_keyboard\":[[{\"text\":\"${label_escaped}\",\"url\":\"${url_escaped}\"}]]}"
  fi
  
  for chat_id in "${CHAT_ID_ARR[@]}"; do
    curl -s -S -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d "chat_id=${chat_id}" \
      --data-urlencode "text=${text}" \
      -d "parse_mode=HTML" \
      ${reply_markup:+--data-urlencode "reply_markup=${reply_markup}"} >>"$LOG_FILE" 2>&1
  done
}

# =================== GCP Project ===================
print_section "☁️  GOOGLE CLOUD PLATFORM"
print_step "03" "Select GCP project"

PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  print_status "error" "No active GCP project found"
  echo ""
  echo -e "${C_INFO}Please set your project using:${RESET}"
  echo -e "${C_HIGHLIGHT}  gcloud config set project YOUR_PROJECT_ID${RESET}"
  exit 1
fi

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')" || true
print_status "success" "Project loaded successfully"
print_key_value "Project ID" "$PROJECT"
print_key_value "Project Number" "$PROJECT_NUMBER"

# =================== Region Selection ===================
print_section "🌎 REGION SELECTION"
print_step "04" "Choose deployment region"

echo ""
echo -e "${C_INFO}Available Regions:${RESET}"
echo -e "  ${C_404}1${RESET}) 🇸🇬 Singapore (asia-southeast1)        ${C_INFO}[Lowest Latency]${RESET}"
echo -e "  ${C_404}2${RESET}) 🇺🇸 United States (us-central1)        ${C_INFO}[Most Stable]${RESET}"
echo -e "  ${C_404}3${RESET}) 🇯🇵 Japan (asia-northeast1)           ${C_INFO}[Fast in Asia]${RESET}"
echo -e "  ${C_404}4${RESET}) 🇪🇺 Belgium (europe-west1)            ${C_INFO}[Europe Region]${RESET}"
echo ""

echo -e -n "${C_INFO}Select region [1-4, default 1]: ${RESET}"
read -r REGION_CHOICE || true

case "${REGION_CHOICE:-1}" in
  1) REGION="asia-southeast1"; REGION_NAME="Singapore" ;;
  2) REGION="us-central1"; REGION_NAME="United States" ;;
  3) REGION="asia-northeast1"; REGION_NAME="Japan" ;;
  4) REGION="europe-west1"; REGION_NAME="Belgium" ;;
  *) REGION="asia-southeast1"; REGION_NAME="Singapore" ;;
esac

print_status "success" "Region selected: $REGION_NAME"
print_key_value "Region Code" "$REGION"
print_key_value "Region Name" "$REGION_NAME"

# =================== Resource Configuration ===================
print_section "⚙️  RESOURCE CONFIGURATION"
print_step "05" "Configure service resources"

echo ""
echo -e "${C_INFO}Resource Recommendations:${RESET}"
echo -e "  ${C_INFO}•${RESET} ${C_404}Development${RESET}: 1 CPU, 1Gi Memory"
echo -e "  ${C_INFO}•${RESET} ${C_SUCCESS}Production${RESET}: 2 CPU, 2Gi Memory"
echo -e "  ${C_INFO}•${RESET} ${C_WARN}High Traffic${RESET}: 4 CPU, 4Gi Memory"
echo ""

echo -e -n "${C_INFO}CPU cores [1/2/4, default 2]: ${RESET}"
read -r CPU_INPUT || true
CPU="${CPU_INPUT:-2}"

echo -e -n "${C_INFO}Memory [1Gi/2Gi/4Gi, default 2Gi]: ${RESET}"
read -r MEMORY_INPUT || true
MEMORY="${MEMORY_INPUT:-2Gi}"

print_status "success" "Resources configured"
print_key_value "CPU Cores" "${CPU} vCPU"
print_key_value "Memory" "$MEMORY"

# =================== Service Configuration ===================
print_section "🔧 SERVICE CONFIGURATION"
print_step "06" "Configure service details"

SERVICE="${SERVICE:-channel404-vless}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

echo -e -n "${C_INFO}Service Name [default: ${SERVICE}]: ${RESET}"
read -r SERVICE_INPUT || true
SERVICE="${SERVICE_INPUT:-$SERVICE}"

echo -e -n "${C_INFO}Request Timeout (seconds) [default: ${TIMEOUT}]: ${RESET}"
read -r TIMEOUT_INPUT || true
TIMEOUT="${TIMEOUT_INPUT:-$TIMEOUT}"

print_status "success" "Service configured"
print_key_value "Service Name" "$SERVICE"
print_key_value "Timeout" "${TIMEOUT}s"
print_key_value "Port" "$PORT"

# =================== Deployment Info ===================
print_section "📅 DEPLOYMENT SCHEDULE"
print_step "07" "Deployment timing information"

export TZ="Asia/Yangon"
START_TIME="$(date +%s)"
END_TIME="$(( START_TIME + 5*3600 ))" # 5 hours for safety

format_time() {
  date -d @"$1" "+%A, %d %B %Y • %I:%M %p"
}

print_key_value "Deployment Start" "$(format_time "$START_TIME")"
print_key_value "Estimated Ready" "$(format_time "$END_TIME")"
print_key_value "Time Zone" "Asia/Yangon (MMT)"

# =================== Animated Progress ===================
show_progress() {
  local label="$1"
  shift
  
  if [[ -t 1 ]]; then
    echo -ne "  ${C_INFO}[${RESET}"
    
    ("$@" >>"$LOG_FILE" 2>&1) &
    local pid=$!
    
    # Animation frames
    local frames=("⣷" "⣯" "⣟" "⡿" "⢿" "⣻" "⣽" "⣾")
    local frame=0
    local dots=""
    
    while kill -0 "$pid" 2>/dev/null; do
      echo -ne "\b${frames[frame]}"
      frame=$(( (frame + 1) % ${#frames[@]} ))
      
      # Add dots for longer operations
      if (( $(echo "$dots" | wc -c) < 20 )); then
        dots="${dots}."
        echo -ne "${C_INFO}${dots}${RESET}"
      fi
      
      sleep 0.2
    done
    
    wait "$pid"
    local rc=$?
    
    if (( rc == 0 )); then
      echo -e "\b${C_SUCCESS}✓${RESET}] ${label} ${C_SUCCESS}COMPLETED${RESET}"
    else
      echo -e "\b${C_ERROR}✗${RESET}] ${label} ${C_ERROR}FAILED${RESET}"
      return $rc
    fi
  else
    "$@" >>"$LOG_FILE" 2>&1
  fi
}

# =================== Enable APIs ===================
print_section "🔌 ENABLING SERVICES"
print_step "08" "Enabling required Google Cloud APIs"

show_progress "Enabling Cloud Run API" \
  gcloud services enable run.googleapis.com --quiet

show_progress "Enabling Cloud Build API" \
  gcloud services enable cloudbuild.googleapis.com --quiet

print_status "success" "All required APIs enabled"

# =================== Deployment ===================
print_section "🚀 DEPLOYMENT IN PROGRESS"
print_step "09" "Deploying VLESS WS to Cloud Run"

print_status "info" "Using official Channel 404 VLESS WS image"
print_status "info" "Protocol: VLESS over WebSocket (WS)"
print_status "info" "Transport: TLS + WebSocket"

IMAGE="docker.io/nkka404/vless-ws:latest"
echo "[Docker Image] ${IMAGE}" >>"$LOG_FILE"

show_progress "Deploying ${SERVICE} to ${REGION}" \
  gcloud run deploy "$SERVICE" \
    --image="$IMAGE" \
    --platform=managed \
    --region="$REGION" \
    --memory="$MEMORY" \
    --cpu="$CPU" \
    --concurrency=1000 \
    --timeout="$TIMEOUT" \
    --allow-unauthenticated \
    --port="$PORT" \
    --min-instances=1 \
    --max-instances=10 \
    --quiet

# =================== Get Deployment URL ===================
print_section "✅ DEPLOYMENT SUCCESSFUL"
print_step "10" "Service details and access information"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')" || true
CANONICAL_HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
URL="https://${CANONICAL_HOST}"

print_status "success" "Service is now LIVE"
print_key_value "Service URL" "${C_ACCENT}${BOLD}${URL}${RESET}"
print_key_value "Region" "$REGION_NAME"
print_key_value "Status" "${C_SUCCESS}ACTIVE${RESET}"

# =================== VLESS Configuration ===================
print_section "🔑 VLESS CONFIGURATION"
print_step "11" "Your VLESS connection details"

VLESS_UUID="ba0e3984-ccc9-48a3-8074-b2f507f41ce8"
VLESS_URI="vless://${VLESS_UUID}@vpn.googleapis.com:443?path=%2F%40nkka404&security=tls&encryption=none&host=${CANONICAL_HOST}&type=ws#CHANNEL-404-VLESS"

echo ""
echo -e "${C_INFO}VLESS Connection URI:${RESET}"
print_divider
echo -e "${C_HIGHLIGHT}${VLESS_URI}${RESET}"
print_divider

echo ""
echo -e "${C_INFO}Quick Import:${RESET}"
echo -e "${C_INFO}1. Copy the URI above${RESET}"
echo -e "${C_INFO}2. Open your V2Ray client${RESET}"
echo -e "${C_INFO}3. Import from clipboard${RESET}"
echo -e "${C_INFO}4. Enable TLS and WebSocket${RESET}"

# =================== Telegram Notification ===================
print_section "📨 NOTIFICATION"
print_step "12" "Sending deployment notification"

if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_CHAT_IDS:-}" ]]; then
  MESSAGE="✅ <b>CHANNEL 404 - VLESS WS DEPLOYED</b>

🏷️ <b>Service:</b> <code>${SERVICE}</code>
🌍 <b>Region:</b> ${REGION_NAME}
🔗 <b>URL:</b> <code>${URL}</code>
⚡ <b>Status:</b> ACTIVE • READY

📡 <b>Protocol:</b> VLESS + WS + TLS
🔑 <b>UUID:</b> <code>${VLESS_UUID}</code>
🛡️ <b>Security:</b> TLS 1.3 • WebSocket

⏰ <b>Deployed:</b> $(date '+%Y-%m-%d %H:%M:%S %Z')

<code>${VLESS_URI}</code>"

  if show_progress "Sending Telegram notification" send_telegram_message "$MESSAGE"; then
    print_status "success" "Notification sent to Telegram"
  else
    print_status "warning" "Telegram notification failed (check logs)"
  fi
else
  print_status "info" "Telegram notification skipped (no token/chat ID)"
fi

# =================== Final Output ===================
print_section "🎉 DEPLOYMENT COMPLETE"
echo ""
echo -e "${C_SUCCESS}${BOLD}✨ VLESS WS Service Successfully Deployed! ✨${RESET}"
echo ""
echo -e "${C_INFO}Service Information:${RESET}"
print_divider
print_key_value "Service Name" "$SERVICE"
print_key_value "Access URL" "$URL"
print_key_value "Region" "$REGION_NAME ($REGION)"
print_key_value "Resources" "${CPU} vCPU • $MEMORY"
print_key_value "Min Instances" "1 (No cold starts)"
print_key_value "Protocol" "VLESS + WebSocket + TLS"
print_divider

echo ""
echo -e "${C_INFO}Next Steps:${RESET}"
echo -e "  1. ${C_404}Test${RESET} your connection with any V2Ray client"
echo -e "  2. ${C_404}Monitor${RESET} usage in Google Cloud Console"
echo -e "  3. ${C_404}Share${RESET} the configuration URI with users"
echo -e "  4. ${C_404}Join${RESET} @premium_channel_404 for updates"

echo ""
echo -e "${C_INFO}Support & Community:${RESET}"
echo -e "  ${C_404}Telegram${RESET}: @premium_channel_404"
echo -e "  ${C_404}Channel${RESET}: @channel_404_news"
echo -e "  ${C_404}Logs${RESET}: ${LOG_FILE}"

echo ""
echo -e "${C_404}${BOLD}Thank you for using CHANNEL 404 Deployment System!${RESET}"
echo -e "${C_INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
