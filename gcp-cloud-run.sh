#!/usr/bin/env bash
set -euo pipefail

# ===== Ensure interactive reads even when run via curl/process substitution =====
if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
  exec </dev/tty
fi

# ===== Logging & error handler =====
LOG_FILE="/tmp/404_vless_$(date +%s).log"
touch "$LOG_FILE"
on_err() {
  local rc=$?
  echo "" | tee -a "$LOG_FILE"
  echo "❌ ERROR: Command failed (exit $rc) at line $LINENO: ${BASH_COMMAND}" | tee -a "$LOG_FILE" >&2
  echo "—— LOG (last 80 lines) ——" >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  echo "📄 Log File: $LOG_FILE" >&2
  
  # Show specific error for deployment failure
  if [[ "${BASH_COMMAND}" == *"gcloud run deploy"* ]]; then
    echo "🔍 Cloud Run Deployment Failed! Possible reasons:" >&2
    echo "   • Cloud Run API not enabled" >&2
    echo "   • Insufficient permissions" >&2
    echo "   • Region not supported" >&2
    echo "   • Image not found: docker.io/nkka404/vless-ws:latest" >&2
    echo "   • Quota exceeded" >&2
  fi
  
  exit $rc
}
trap on_err ERR

# =================== CHANNEL 404 Custom UI ===================
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RESET=$'\e[0m'; BOLD=$'\e[1m'
  C_404_RED=$'\e[38;5;196m'      # Bright Red
  C_404_BLUE=$'\e[38;5;39m'      # Bright Blue
  C_404_GREEN=$'\e[38;5;46m'     # Bright Green
  C_404_YELLOW=$'\e[38;5;226m'   # Bright Yellow
  C_404_PURPLE=$'\e[38;5;93m'    # Purple
  C_404_GRAY=$'\e[38;5;245m'     # Gray
  C_404_CYAN=$'\e[38;5;51m'      # Cyan
else
  RESET= BOLD= C_404_RED= C_404_BLUE= C_404_GREEN= C_404_YELLOW= C_404_PURPLE= C_404_GRAY= C_404_CYAN=
fi

# =================== CHANNEL 404 Banner ===================
show_404_banner() {
  clear
  printf "\n\n"
  printf "${C_404_RED}${BOLD}"
  printf "╔══════════════════════════════════════════════════════════════════╗\n"
  printf "║    ${C_404_CYAN} ___   ___          ________          ___   ___                               ${C_404_RED}\n"
  printf "║    ${C_404_CYAN}|\  \ |\  \        |\   __  \        |\  \ |\  \                              ${C_404_RED}\n"
  printf "║    ${C_404_CYAN}\ \  \|_\  \       \ \  \|\  \       \ \  \|_\  \                             ${C_404_RED}\n"
  printf "║    ${C_404_CYAN} \ \______  \       \ \  \/\  \       \ \______  \                            ${C_404_RED}\n"
  printf "║    ${C_404_CYAN}  \|_____|\  \       \ \  \/\  \       \|_____|\  \                           ${C_404_RED}\n"
  printf "║    ${C_404_CYAN}         \ \__\       \ \_______\             \ \__\                          ${C_404_RED}\n"
  printf "║    ${C_404_CYAN}          \|__|        \|_______|              \|__|                          ${C_404_RED}\n"
  printf "║                                                                                               ${C_404_RED}\n"
  printf "║         ${C_404_YELLOW}🚀 VLESS WS DEPLOYMENT SYSTEM => VERSION - 2.0                         ${C_404_RED}\n"
  printf "║         ${C_404_GREEN}⚡ Powered by CHANNEL 404                                               ${C_404_RED}\n"
  printf "║                                                                                               ${C_404_RED}\n"
  printf "╚══════════════════════════════════════════════════════════════════╝${RESET}\n"
  printf "\n\n"
}

# =================== Custom UI Functions ===================
show_step() {
  local step_num="$1"
  local step_title="$2"
  printf "\n${C_404_PURPLE}${BOLD}┌─── STEP %s ──────────────────────────────────────────┐${RESET}\n" "$step_num"
  printf "${C_404_PURPLE}${BOLD}│${RESET} ${C_404_CYAN}%s${RESET}\n" "$step_title"
  printf "${C_404_PURPLE}${BOLD}└──────────────────────────────────────────────────────┘${RESET}\n"
}

show_success() {
  printf "${C_404_GREEN}${BOLD}✓${RESET} ${C_404_GREEN}%s${RESET}\n" "$1"
}

show_info() {
  printf "${C_404_BLUE}${BOLD}ℹ${RESET} ${C_404_BLUE}%s${RESET}\n" "$1"
}

show_warning() {
  printf "${C_404_YELLOW}${BOLD}⚠${RESET} ${C_404_YELLOW}%s${RESET}\n" "$1"
}

show_error() {
  printf "${C_404_RED}${BOLD}✗${RESET} ${C_404_RED}%s${RESET}\n" "$1"
}

show_divider() {
  printf "${C_404_GRAY}%s${RESET}\n" "──────────────────────────────────────────────────────────"
}

show_kv() {
  printf "   ${C_404_GRAY}%s${RESET}  ${C_404_CYAN}%s${RESET}\n" "$1" "$2"
}

# =================== Progress Spinner ===================
run_with_progress() {
  local label="$1"; shift
  local cmd_output
  local temp_file=$(mktemp)
  
  if [[ -t 1 ]]; then
    printf "\e[?25l"
    # Run command and capture output
    ("$@" 2>&1 | tee "$temp_file") >>"$LOG_FILE" 2>&1 &
    local pid=$!
    local pct=5
    
    while kill -0 "$pid" 2>/dev/null; do
      local step=$(( (RANDOM % 9) + 2 ))
      pct=$(( pct + step ))
      (( pct > 95 )) && pct=95
      printf "\r${C_404_PURPLE}⟳${RESET} ${C_404_CYAN}%s...${RESET} [${C_404_YELLOW}%s%%${RESET}]" "$label" "$pct"
      
      # Check if there's any error in output
      if grep -i "error\|failed\|denied" "$temp_file" 2>/dev/null | grep -v "grep" | head -1; then
        break
      fi
      
      sleep "$(awk -v r=$RANDOM 'BEGIN{s=0.08+(r%7)/100; printf "%.2f", s }')"
    done
    
    wait "$pid" 2>/dev/null || true
    local rc=$?
    printf "\r"
    
    # Check for errors in output
    if grep -qi "error\|failed\|denied\|permission" "$temp_file"; then
      printf "${C_404_RED}✗${RESET} ${C_404_RED}%s failed${RESET}\n" "$label"
      cat "$temp_file" | grep -i "error\|failed\|denied\|permission" | head -3 | while read line; do
        echo "   ${C_404_RED}→${RESET} $line"
      done
      rm -f "$temp_file"
      printf "\e[?25h"
      return 1
    elif (( rc==0 )); then
      printf "${C_404_GREEN}✓${RESET} ${C_404_GREEN}%s...${RESET} [${C_404_GREEN}100%%${RESET}]\n" "$label"
    else
      printf "${C_404_RED}✗${RESET} ${C_404_RED}%s failed (exit $rc)${RESET}\n" "$label"
      tail -5 "$temp_file" | while read line; do
        echo "   ${C_404_RED}→${RESET} $line"
      done
      rm -f "$temp_file"
      printf "\e[?25h"
      return $rc
    fi
    rm -f "$temp_file"
    printf "\e[?25h"
  else
    "$@" >>"$LOG_FILE" 2>&1
  fi
}

# Show banner
show_404_banner

# =================== Step 1: Telegram Config ===================
show_step "01" "Telegram Configuration Setup"

TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_IDS="${TELEGRAM_CHAT_IDS:-${TELEGRAM_CHAT_ID:-}}"

if [[ ( -z "${TELEGRAM_TOKEN}" || -z "${TELEGRAM_CHAT_IDS}" ) && -f .env ]]; then
  set -a; source ./.env; set +a
  show_info "Loaded configuration from .env file"
fi

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🔑 Telegram Bot Configuration${RESET}                      ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

read -rp "${C_404_GREEN}🤖 Enter Telegram Bot Token (optional):${RESET} " _tk || true
[[ -n "${_tk:-}" ]] && TELEGRAM_TOKEN="$_tk"
if [[ -z "${TELEGRAM_TOKEN:-}" ]]; then
  show_warning "Telegram token is empty. Deployment will continue without notifications."
else
  show_success "Telegram token configured"
fi

read -rp "${C_404_GREEN}👤 Enter Owner/Channel Chat ID(s) (optional):${RESET} " _ids || true
[[ -n "${_ids:-}" ]] && TELEGRAM_CHAT_IDS="${_ids// /}"

DEFAULT_LABEL="Join CHANNEL 404"
DEFAULT_URL="https://t.me/premium_channel_404"
BTN_LABELS=(); BTN_URLS=()

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🔘 Inline Button Configuration (Optional)${RESET}            ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

read -rp "${C_404_GREEN}➕ Add URL button(s)? [y/N]:${RESET} " _addbtn || true
if [[ "${_addbtn:-}" =~ ^([yY]|yes)$ ]]; then
  i=0
  while true; do
    printf "\n${C_404_GRAY}── Button $((i+1)) ──${RESET}\n"
    read -rp "${C_404_GREEN}🔖 Label [default: ${DEFAULT_LABEL}]:${RESET} " _lbl || true
    if [[ -z "${_lbl:-}" ]]; then
      BTN_LABELS+=("${DEFAULT_LABEL}")
      BTN_URLS+=("${DEFAULT_URL}")
      show_success "Added: ${DEFAULT_LABEL} → ${DEFAULT_URL}"
    else
      read -rp "${C_404_GREEN}🔗 URL (http/https):${RESET} " _url || true
      if [[ -n "${_url:-}" && "${_url}" =~ ^https?:// ]]; then
        BTN_LABELS+=("${_lbl}")
        BTN_URLS+=("${_url}")
        show_success "Added: ${_lbl} → ${_url}"
      else
        show_warning "Skipped (invalid or empty URL)"
      fi
    fi
    i=$(( i + 1 ))
    (( i >= 3 )) && break
    read -rp "${C_404_GREEN}➕ Add another button? [y/N]:${RESET} " _more || true
    [[ "${_more:-}" =~ ^([yY]|yes)$ ]] || break
  done
fi

CHAT_ID_ARR=()
IFS=',' read -r -a CHAT_ID_ARR <<< "${TELEGRAM_CHAT_IDS:-}" || true

json_escape(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

tg_send(){
  local text="$1" RM=""
  if [[ -z "${TELEGRAM_TOKEN:-}" || ${#CHAT_ID_ARR[@]} -eq 0 ]]; then return 0; fi
  if (( ${#BTN_LABELS[@]} > 0 )); then
    local L1 U1 L2 U2 L3 U3
    [[ -n "${BTN_LABELS[0]:-}" ]] && L1="$(json_escape "${BTN_LABELS[0]}")" && U1="$(json_escape "${BTN_URLS[0]}")"
    [[ -n "${BTN_LABELS[1]:-}" ]] && L2="$(json_escape "${BTN_LABELS[1]}")" && U2="$(json_escape "${BTN_URLS[1]}")"
    [[ -n "${BTN_LABELS[2]:-}" ]] && L3="$(json_escape "${BTN_LABELS[2]}")" && U3="$(json_escape "${BTN_URLS[2]}")"
    if (( ${#BTN_LABELS[@]} == 1 )); then
      RM="{\"inline_keyboard\":[[{\"text\":\"${L1}\",\"url\":\"${U1}\"}]]}"
    elif (( ${#BTN_LABELS[@]} == 2 )); then
      RM="{\"inline_keyboard\":[[{\"text\":\"${L1}\",\"url\":\"${U1}\"}],[{\"text\":\"${L2}\",\"url\":\"${U2}\"}]]}"
    else
      RM="{\"inline_keyboard\":[[{\"text\":\"${L1}\",\"url\":\"${U1}\"}],[{\"text\":\"${L2}\",\"url\":\"${U2}\"},{\"text\":\"${L3}\",\"url\":\"${U3}\"}]]}"
    fi
  fi
  for _cid in "${CHAT_ID_ARR[@]}"; do
    curl -s -S -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d "chat_id=${_cid}" \
      --data-urlencode "text=${text}" \
      -d "parse_mode=HTML" \
      ${RM:+--data-urlencode "reply_markup=${RM}"} >>"$LOG_FILE" 2>&1 || true
    show_success "Telegram notification sent → ${_cid}"
  done
}

# =================== Step 2: Project ===================
show_step "02" "GCP Project Configuration"

PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  show_error "No active GCP project found."
  show_info "Please run: ${C_404_CYAN}gcloud config set project <YOUR_PROJECT_ID>${RESET}"
  exit 1
fi

# Check if project exists and is accessible
if ! gcloud projects describe "$PROJECT" &>/dev/null; then
  show_error "Project '$PROJECT' not found or not accessible"
  exit 1
fi

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')" || true
show_success "Project loaded successfully"
show_kv "Project ID:" "$PROJECT"
show_kv "Project Number:" "$PROJECT_NUMBER"

# =================== Step 3: Protocol ===================
show_step "03" "Protocol Selection"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}📡 Selected Protocol: VLESS WS${RESET}                         ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

PROTO="vless-ws"
IMAGE="docker.io/nkka404/vless-ws:latest"

show_success "Protocol: ${C_404_CYAN}VLESS WebSocket${RESET}"
show_info "Docker Image: ${C_404_GRAY}$IMAGE${RESET}"
echo "[Docker Image] ${IMAGE}" >>"$LOG_FILE"

# =================== Step 4: Region ===================
show_step "04" "Region Selection"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🌍 Select Deployment Region${RESET}                            ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

echo "  1) ${C_404_BLUE}🇺🇸 United States${RESET} (us-central1) - ${C_404_GREEN}Recommended${RESET}"
echo "  2) ${C_404_BLUE}🇸🇬 Singapore${RESET} (asia-southeast1)"
echo "  3) ${C_404_BLUE}🇮🇩 Indonesia${RESET} (asia-southeast2)"
echo "  4) ${C_404_BLUE}🇯🇵 Japan${RESET} (asia-northeast1)"
echo "  5) ${C_404_BLUE}🇪🇺 Belgium${RESET} (europe-west1)"
echo "  6) ${C_404_BLUE}🇮🇳 India${RESET} (asia-south1)"
printf "\n"

read -rp "${C_404_GREEN}Choose region [1-6, default 1]:${RESET} " _r || true
case "${_r:-1}" in
  2) REGION="asia-southeast1" ;;
  3) REGION="asia-southeast2" ;;
  4) REGION="asia-northeast1" ;;
  5) REGION="europe-west1" ;;
  6) REGION="asia-south1" ;;
  *) REGION="us-central1" ;;
esac

show_success "Selected Region: ${C_404_CYAN}$REGION${RESET}"

# =================== Step 5: Resources ===================
show_step "05" "Resource Configuration"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}⚙️ Compute Resources${RESET}                                  ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

read -rp "${C_404_GREEN}CPU Cores [1/2/4/6, default 2]:${RESET} " _cpu || true
CPU="${_cpu:-2}"

printf "\n${C_404_GRAY}Available Memory Options:${RESET}\n"
echo "  ${C_404_GRAY}•${RESET} 512Mi  ${C_404_GRAY}•${RESET} 1Gi    ${C_404_GRAY}•${RESET} 2Gi (Recommended)"
echo "  ${C_404_GRAY}•${RESET} 4Gi    ${C_404_GRAY}•${RESET} 8Gi    ${C_404_GRAY}•${RESET} 16Gi"
printf "\n"

read -rp "${C_404_GREEN}Memory [default 2Gi]:${RESET} " _mem || true
MEMORY="${_mem:-2Gi}"

show_success "Resource Configuration"
show_kv "CPU Cores:" "$CPU"
show_kv "Memory:" "$MEMORY"

# =================== Step 6: Service Name ===================
show_step "06" "Service Configuration"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🪪 Service Details${RESET}                                    ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

SERVICE="${SERVICE:-channel404-vless}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

read -rp "${C_404_GREEN}Service Name [default: ${SERVICE}]:${RESET} " _svc || true
SERVICE="${_svc:-$SERVICE}"

# Validate service name (Cloud Run requirements)
if [[ ! "$SERVICE" =~ ^[a-z]([-a-z0-9]*[a-z0-9])?$ ]]; then
  show_error "Invalid service name. Use lowercase letters, numbers, and hyphens only. Must start with letter and end with letter/number."
  exit 1
fi

show_success "Service Configuration"
show_kv "Service Name:" "$SERVICE"
show_kv "Port:" "$PORT"
show_kv "Timeout:" "${TIMEOUT}s"

# =================== Step 7: Timezone Setup ===================
show_step "07" "Deployment Schedule"

export TZ="Asia/Yangon"
START_EPOCH="$(date +%s)"
END_EPOCH="$(( START_EPOCH + 5*3600 ))"
fmt_dt(){ date -d @"$1" "+%d.%m.%Y %I:%M %p"; }
START_LOCAL="$(fmt_dt "$START_EPOCH")"
END_LOCAL="$(fmt_dt "$END_EPOCH")"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🕒 Deployment Time${RESET}                                    ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

show_kv "Start Time:" "$START_LOCAL"
show_kv "End Time:" "$END_LOCAL"
show_kv "Timezone:" "Asia/Yangon"
show_info "Deployment will complete within 5 minutes"

# =================== Step 8: Enable APIs ===================
show_step "08" "GCP API Enablement"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🔧 Enabling Required APIs${RESET}                             ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

# Check if APIs are already enabled
APIS_TO_ENABLE=("run.googleapis.com" "cloudbuild.googleapis.com")
for api in "${APIS_TO_ENABLE[@]}"; do
  if ! gcloud services list --enabled --filter="config.name:$api" --format="value(config.name)" | grep -q "$api"; then
    show_info "Enabling $api..."
    run_with_progress "Enabling $api" gcloud services enable "$api" --quiet
  else
    show_success "$api already enabled"
  fi
done

show_success "All required APIs enabled"

# =================== Step 9: Pre-deployment Checks ===================
show_step "09" "Pre-deployment Checks"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🔍 Running Pre-deployment Checks${RESET}                       ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

# Check authentication
if ! gcloud auth print-access-token &>/dev/null; then
  show_error "Not authenticated. Please run: gcloud auth login"
  exit 1
fi
show_success "Authentication valid"

# Check if region is supported for Cloud Run
if ! gcloud run regions list --format="value(locationId)" 2>/dev/null | grep -q "$REGION"; then
  show_warning "Region $REGION might not support Cloud Run. Will attempt anyway."
else
  show_success "Region $REGION supports Cloud Run"
fi

# Check if service name already exists
if gcloud run services describe "$SERVICE" --region="$REGION" --quiet &>/dev/null; then
  show_warning "Service '$SERVICE' already exists in $REGION. It will be updated/replaced."
else
  show_success "Service name '$SERVICE' is available"
fi

# Test pulling the image (optional)
show_info "Testing image availability..."
if docker pull "$IMAGE" --quiet 2>/dev/null; then
  show_success "Image $IMAGE is accessible"
else
  show_warning "Cannot pull image directly. Will attempt deployment anyway."
fi

# =================== Step 10: Deploy ===================
show_step "10" "Cloud Run Deployment"

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}🚀 Deploying VLESS WS Service${RESET}                         ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

show_info "Deployment Configuration Summary:"
show_kv "Protocol:" "VLESS WS"
show_kv "Region:" "$REGION"
show_kv "Service:" "$SERVICE"
show_kv "Resources:" "${CPU} vCPU / ${MEMORY}"
show_kv "Image:" "${C_404_GRAY}docker.io/nkka404/vless-ws:latest${RESET}"
printf "\n"

# Build deployment command
DEPLOY_CMD=(
  gcloud run deploy "$SERVICE"
  --image="$IMAGE"
  --platform=managed
  --region="$REGION"
  --memory="$MEMORY"
  --cpu="$CPU"
  --concurrency=1000
  --timeout="$TIMEOUT"
  --allow-unauthenticated
  --port="$PORT"
  --min-instances=1
  --quiet
)

echo "[DEBUG] Running: ${DEPLOY_CMD[*]}" >> "$LOG_FILE"

# Run deployment with progress indicator and better error handling
if ! run_with_progress "Deploying ${SERVICE} to Cloud Run" "${DEPLOY_CMD[@]}"; then
  show_error "Deployment failed!"
  
  # Check specific error conditions
  echo "=== Diagnostics ===" >&2
  
  # Check API
  if ! gcloud services list --enabled | grep -q run.googleapis.com; then
    show_error "Cloud Run API is not enabled"
    run_with_progress "Enabling Cloud Run API" gcloud services enable run.googleapis.com
  fi
  
  # Check quota/limits
  show_info "Checking quotas..."
  gcloud run regions list 2>/dev/null || show_warning "Cannot list regions"
  
  # Check permissions
  if ! gcloud run services list --region="$REGION" --quiet &>/dev/null; then
    show_error "Insufficient permissions to deploy to Cloud Run in $REGION"
    show_info "Required roles: roles/run.admin or roles/run.developer"
  fi
  
  # Show last 20 lines of log
  echo "=== Last 20 lines of log ===" >&2
  tail -20 "$LOG_FILE" >&2
  
  exit 1
fi

# =================== Step 11: Get Service URL ===================
show_step "11" "Retrieving Service Information"

# Get the actual URL after deployment
SERVICE_URL=$(gcloud run services describe "$SERVICE" --region="$REGION" --format='value(status.url)' 2>/dev/null || true)

if [[ -z "$SERVICE_URL" ]]; then
  PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')" || true
  CANONICAL_HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
  SERVICE_URL="https://${CANONICAL_HOST}"
fi

printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}✅ Deployment Successful${RESET}                               ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

show_success "VLESS WS Service is now running!"
show_divider

printf "\n${C_404_GREEN}${BOLD}📡 SERVICE ENDPOINT:${RESET}\n"
printf "   ${C_404_CYAN}${BOLD}%s${RESET}\n\n" "${SERVICE_URL}"

# =================== VLESS Configuration ===================
VLESS_UUID="ba0e3984-ccc9-48a3-8074-b2f507f41ce8"
URI="vless://${VLESS_UUID}@vpn.googleapis.com:443?path=%2F%40nkka404&security=tls&encryption=none&host=$(basename ${SERVICE_URL#https://})&type=ws&sni=vpn.googleapis.com#CHANNEL-404-VLESS-WS"

printf "${C_404_GREEN}${BOLD}🔑 VLESS CONFIGURATION:${RESET}\n"
printf "   ${C_404_CYAN}%s${RESET}\n\n" "${URI}"

printf "${C_404_GREEN}${BOLD}📋 CONFIGURATION DETAILS:${RESET}\n"
show_kv "UUID:" "$VLESS_UUID"
show_kv "Host:" "vpn.googleapis.com"
show_kv "Port:" "443"
show_kv "Path:" "/@nkka404"
show_kv "Security:" "TLS"
show_kv "Transport:" "WebSocket"
show_kv "SNI:" "vpn.googleapis.com"
show_divider

# =================== QR Code Display ===================
printf "\n${C_404_GREEN}${BOLD}📱 QR CODE (Scan with V2Ray client):${RESET}\n"
show_info "Generating QR code for quick configuration..."

# Check if qrencode is installed
if command -v qrencode &>/dev/null; then
  qrencode -t ANSI256 "$URI" || show_warning "QR code generation failed"
else
  show_warning "qrencode not installed. Install with: apt-get install qrencode or brew install qrencode"
  # Fallback to ASCII QR
  if command -v curl &>/dev/null; then
    curl -s "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${URI}" -o /tmp/qr.png 2>/dev/null && \
    show_info "QR saved to /tmp/qr.png" || true
  fi
fi

echo "[QR Code URL: $URI]" >> "$LOG_FILE"

# =================== Telegram Notification ===================
show_step "12" "Telegram Notification"

if [[ -n "${TELEGRAM_TOKEN:-}" && ${#CHAT_ID_ARR[@]} -gt 0 ]]; then
  MSG=$(cat <<EOF
✅ <b>VLESS WS Deployment Success</b>
━━━━━━━━━━━━━━━━━━━━━━━━━━
<blockquote>🌍 <b>Region:</b> ${REGION}
📡 <b>Protocol:</b> VLESS WebSocket
🔗 <b>Endpoint:</b> <a href="${SERVICE_URL}">${SERVICE_URL}</a>
⚙️ <b>Resources:</b> ${CPU} vCPU / ${MEMORY}</blockquote>
🔑 <b>VLESS Configuration:</b>
<pre><code>${URI}</code></pre>
<blockquote>🕒 <b>Deployed:</b> ${START_LOCAL}
⏳ <b>Expires:</b> ${END_LOCAL}</blockquote>
━━━━━━━━━━━━━━━━━━━━━━━━━━
<b>Powered by CHANNEL 404</b>
EOF
)

  tg_send "${MSG}"
  show_success "Telegram notification sent successfully"
else
  show_info "Telegram notifications not configured, skipping..."
fi

# =================== Final Output ===================
printf "\n${C_404_YELLOW}┌──────────────────────────────────────────────────────┐${RESET}\n"
printf "${C_404_YELLOW}│${RESET} ${C_404_CYAN}✨ DEPLOYMENT COMPLETE${RESET}                                ${C_404_YELLOW}│${RESET}\n"
printf "${C_404_YELLOW}└──────────────────────────────────────────────────────┘${RESET}\n\n"

show_success "VLESS WS service deployed successfully!"
show_info "Service URL: ${C_404_CYAN}${SERVICE_URL}${RESET}"
show_info "Configuration saved to log file"
show_kv "Log File:" "$LOG_FILE"
show_kv "Service Name:" "$SERVICE"
show_kv "Region:" "$REGION"

printf "\n${C_404_PURPLE}${BOLD}💡 IMPORTANT NOTES:${RESET}\n"
echo "  ${C_404_GRAY}•${RESET} Service is configured with ${C_404_GREEN}warm instances${RESET} (min-instances=1)"
echo "  ${C_404_GRAY}•${RESET} ${C_404_GREEN}No cold start${RESET} delays for initial connections"
echo "  ${C_404_GRAY}•${RESET} Configured for ${C_404_GREEN}high concurrency${RESET} (1000 concurrent requests)"
echo "  ${C_404_GRAY}•${RESET} ${C_404_GREEN}Publicly accessible${RESET} via the endpoint"
echo "  ${C_404_GRAY}•${RESET} Auto-scales based on traffic demand"
printf "\n"

show_divider
printf "\n${C_404_RED}${BOLD}4 0 4${RESET} ${C_404_GRAY}|${RESET} ${C_404_CYAN}VLESS WebSocket Deployment System${RESET} ${C_404_GRAY}|${RESET} ${C_404_GREEN}v2.1${RESET}\n"
printf "${C_404_GRAY}──────────────────────────────────────────────────────────${RESET}\n\n"

# =================== Test Connection ===================
printf "\n${C_404_CYAN}${BOLD}Testing deployment...${RESET}\n"
if command -v curl &>/dev/null; then
  if curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL" 2>/dev/null | grep -q "200\|403\|401"; then
    show_success "Service is responding"
  else
    show_warning "Service might not be ready yet. Wait a few seconds and try accessing: $SERVICE_URL"
  fi
fi
