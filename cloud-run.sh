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
  exit $rc
}
trap on_err ERR

# =================== CHANNEL 404 Custom Colors ===================
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RESET=$'\e[0m'; BOLD=$'\e[1m'; DIM=$'\e[2m'
  # Channel 404 Brand Colors
  C_404_PRIMARY=$'\e[38;5;200m'     # Magenta/Pink
  C_404_SECONDARY=$'\e[38;5;39m'    # Cyan/Blue
  C_404_ACCENT=$'\e[38;5;226m'      # Yellow
  C_404_SUCCESS=$'\e[38;5;46m'      # Green
  C_404_WARNING=$'\e[38;5;214m'     # Orange
  C_404_ERROR=$'\e[38;5;196m'       # Red
  C_404_GREY=$'\e[38;5;245m'        # Grey
else
  RESET= BOLD= DIM= C_404_PRIMARY= C_404_SECONDARY= C_404_ACCENT= 
  C_404_SUCCESS= C_404_WARNING= C_404_ERROR= C_404_GREY=
fi

# =================== CHANNEL 404 UI Components ===================
channel404_banner() {
  printf "\n${C_404_PRIMARY}${BOLD}"
  printf "╔══════════════════════════════════════════════════════════════╗\n"
  printf "║${C_404_SECONDARY}██╗   ██╗██╗     ███████╗███████╗███████╗${C_404_PRIMARY}║\n"
  printf "║${C_404_SECONDARY}██║   ██║██║     ██╔════╝██╔════╝██╔════╝${C_404_PRIMARY}║\n"
  printf "║${C_404_SECONDARY}██║   ██║██║     ███████╗███████╗███████╗${C_404_PRIMARY}║\n"
  printf "║${C_404_SECONDARY}██║   ██║██║     ╚════██║╚════██║╚════██║${C_404_PRIMARY}║\n"
  printf "║${C_404_SECONDARY}╚██████╔╝███████╗███████║███████║███████║${C_404_PRIMARY}║\n"
  printf "║${C_404_SECONDARY} ╚═════╝ ╚══════╝╚══════╝╚══════╝╚══════╝${C_404_PRIMARY}║\n"
  printf "╠══════════════════════════════════════════════════════════════╣${RESET}\n"
  printf "${C_404_PRIMARY}${BOLD}║${C_404_ACCENT}    ✦ C L O U D   R U N   D E P L O Y M E N T   S U I T E ✦    ${C_404_PRIMARY}║\n"
  printf "╚══════════════════════════════════════════════════════════════╝${RESET}\n\n"
}

channel404_section() {
  local title="$1"
  printf "\n${C_404_PRIMARY}${BOLD}⟣ ${title} ${C_404_GREY}"
  printf "%0.s─" $(seq 1 $((60 - ${#title} - 3)))
  printf "${RESET}\n"
}

channel404_step() {
  local num="$1" title="$2"
  printf "${C_404_SECONDARY}${BOLD}[${num}]${RESET} ${BOLD}${title}${RESET}\n"
}

channel404_status() {
  local emoji="$1" msg="$2" color=""
  case "$emoji" in
    "✅") color="$C_404_SUCCESS" ;;
    "⚠️") color="$C_404_WARNING" ;;
    "❌") color="$C_404_ERROR" ;;
    "🔧") color="$C_404_SECONDARY" ;;
    "🚀") color="$C_404_ACCENT" ;;
    *) color="$C_404_SECONDARY" ;;
  esac
  printf "${color}${emoji}${RESET} ${msg}\n"
}

channel404_divider() {
  printf "${C_404_GREY}┌%0.s─" $(seq 1 58)
  printf "┐${RESET}\n"
}

channel404_box() {
  local content="$1"
  printf "${C_404_GREY}│${RESET} %-56s ${C_404_GREY}│${RESET}\n" "$content"
}

channel404_divider_end() {
  printf "${C_404_GREY}└%0.s─" $(seq 1 58)
  printf "┘${RESET}\n"
}

# =================== Start CHANNEL 404 UI ===================
clear
channel404_banner

# =================== Step 1: Telegram Config ===================
channel404_section "TELEGRAM CONFIGURATION"
channel404_step "01" "Telegram Bot Setup"

TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_IDS="${TELEGRAM_CHAT_IDS:-${TELEGRAM_CHAT_ID:-}}"

if [[ ( -z "${TELEGRAM_TOKEN}" || -z "${TELEGRAM_CHAT_IDS}" ) && -f .env ]]; then
  set -a; source ./.env; set +a
fi

printf "\n${C_404_SECONDARY}📱 Telegram Integration${RESET}\n"
channel404_divider
channel404_box "Required for deployment notifications and configuration sharing"
channel404_box "Create bot via @BotFather and get Token & Chat ID"
channel404_divider_end

read -rp "${C_404_ACCENT}🤖 Bot Token: ${RESET}" _tk || true
[[ -n "${_tk:-}" ]] && TELEGRAM_TOKEN="$_tk"

if [[ -z "${TELEGRAM_TOKEN:-}" ]]; then
  channel404_status "⚠️" "Telegram disabled - notifications will be skipped"
else
  channel404_status "✅" "Bot token captured"
fi

read -rp "${C_404_ACCENT}👤 Owner/Chat ID(s): ${RESET}" _ids || true
[[ -n "${_ids:-}" ]] && TELEGRAM_CHAT_IDS="${_ids// /}"

CHAT_ID_ARR=()
IFS=',' read -r -a CHAT_ID_ARR <<< "${TELEGRAM_CHAT_IDS:-}" || true

# =================== Step 2: Project Verification ===================
channel404_section "GOOGLE CLOUD CONFIGURATION"
channel404_step "02" "GCP Project Setup"

PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  channel404_status "❌" "No active GCP project found"
  printf "\n${C_404_SECONDARY}Quick fix:${RESET}\n"
  printf "  ${C_404_GREY}gcloud config set project YOUR_PROJECT_ID${RESET}\n"
  exit 1
fi

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')" || true
channel404_status "✅" "Project: ${C_404_ACCENT}${PROJECT}${RESET} (${PROJECT_NUMBER})"

# =================== Step 3: Protocol Selection ===================
channel404_section "PROTOCOL CONFIGURATION"
channel404_step "03" "Select Protocol"

printf "\n${C_404_SECONDARY}⚡ Available Protocols:${RESET}\n"
channel404_divider
channel404_box "${C_404_SUCCESS}✓ VLESS WebSocket (WS) ${C_404_GREY}- Recommended${RESET}"
channel404_box "  • Support CDN (Cloudflare)"
channel404_box "  • High performance"
channel404_box "  • TLS encryption"
channel404_divider_end

PROTO="vless-ws"
IMAGE="docker.io/nkka404/vless-ws:latest"
channel404_status "✅" "Protocol selected: ${C_404_ACCENT}${PROTO^^}${RESET}"

# =================== Step 4: Region Selection ===================
channel404_section "REGION SELECTION"
channel404_step "04" "Choose Deployment Region"

printf "\n${C_404_SECONDARY}🌍 Available Regions:${RESET}\n"
channel404_divider
channel404_box "1. ${C_404_SUCCESS}Singapore${RESET} (asia-southeast1) - Low latency"
channel404_box "2. ${C_404_WARNING}United States${RESET} (us-central1) - Global"
channel404_box "3. ${C_404_SUCCESS}Indonesia${RESET} (asia-southeast2) - SEA optimized"
channel404_box "4. ${C_404_SUCCESS}Japan${RESET} (asia-northeast1) - Asia optimized"
channel404_divider_end

read -rp "${C_404_ACCENT}📍 Select region [1-4, default 1]: ${RESET}" _r || true
case "${_r:-1}" in
  2) REGION="us-central1" ;;
  3) REGION="asia-southeast2" ;;
  4) REGION="asia-northeast1" ;;
  *) REGION="asia-southeast1" ;;
esac

channel404_status "✅" "Region: ${C_404_ACCENT}${REGION}${RESET}"

# =================== Step 5: Resource Allocation ===================
channel404_section "RESOURCE ALLOCATION"
channel404_step "05" "CPU & Memory Configuration"

printf "\n${C_404_SECONDARY}💾 Resource Tiers:${RESET}\n"
channel404_divider
channel404_box "Tier 1: 1 vCPU / 2Gi RAM ${C_404_GREY}(~100-200 users)${RESET}"
channel404_box "Tier 2: 2 vCPU / 4Gi RAM ${C_404_GREY}(~200-500 users)${RESET}"
channel404_box "Tier 3: 4 vCPU / 8Gi RAM ${C_404_GREY}(~500-1000 users)${RESET}"
channel404_divider_end

read -rp "${C_404_ACCENT}⚙️  CPU cores [1/2/4, default 2]: ${RESET}" _cpu || true
CPU="${_cpu:-2}"

read -rp "${C_404_ACCENT}🧠 Memory [2Gi/4Gi/8Gi, default 4Gi]: ${RESET}" _mem || true
MEMORY="${_mem:-4Gi}"

channel404_status "✅" "Resources: ${C_404_ACCENT}${CPU} vCPU / ${MEMORY}${RESET}"

# =================== Step 6: Service Configuration ===================
channel404_section "SERVICE CONFIGURATION"
channel404_step "06" "Service Settings"

SERVICE="${SERVICE:-channel404-vless}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

read -rp "${C_404_ACCENT}🏷️  Service name [default: ${SERVICE}]: ${RESET}" _svc || true
SERVICE="${_svc:-$SERVICE}"

channel404_status "✅" "Service: ${C_404_ACCENT}${SERVICE}${RESET}"
channel404_status "🔧" "Port: ${PORT} | Timeout: ${TIMEOUT}s"

# =================== Timezone Setup ===================
export TZ="Asia/Yangon"
START_EPOCH="$(date +%s)"
END_EPOCH="$(( START_EPOCH + 5*3600 ))"
fmt_dt(){ date -d @"$1" "+%d.%m.%Y %I:%M %p"; }
START_LOCAL="$(fmt_dt "$START_EPOCH")"
END_LOCAL="$(fmt_dt "$END_EPOCH")"

channel404_section "DEPLOYMENT TIMELINE"
channel404_step "07" "Deployment Schedule"

printf "\n"
channel404_divider
channel404_box "${C_404_SUCCESS}▶ START${RESET}   ${START_LOCAL}"
channel404_box "${C_404_WARNING}⏸︎ END${RESET}     ${END_LOCAL}"
channel404_box "${C_404_SECONDARY}⏱️ DURATION${RESET} 5 hours"
channel404_divider_end

# =================== Progress Spinner ===================
channel404_progress() {
  local label="$1"; shift
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local frame_idx=0
  local pct=5
  
  ( "$@" ) >>"$LOG_FILE" 2>&1 &
  local pid=$!
  
  if [[ -t 1 ]]; then
    printf "\e[?25l"
    while kill -0 "$pid" 2>/dev/null; do
      frame_idx=$(( (frame_idx + 1) % ${#frames[@]} ))
      local step=$(( (RANDOM % 7) + 3 ))
      pct=$(( pct + step ))
      (( pct > 95 )) && pct=95
      printf "\r${C_404_PRIMARY}${frames[frame_idx]}${RESET} ${label} ${C_404_GREY}[${pct}%%]${RESET}"
      sleep 0.1
    done
    wait "$pid"; local rc=$?
    printf "\r"
    if (( rc==0 )); then
      printf "${C_404_SUCCESS}✅${RESET} ${label} ${C_404_GREY}[100%%]${RESET}\n"
    else
      printf "${C_404_ERROR}❌${RESET} ${label} failed\n"
      return $rc
    fi
    printf "\e[?25h"
  else
    wait "$pid"
  fi
}

# =================== Step 8: Enable APIs ===================
channel404_section "GOOGLE CLOUD SETUP"
channel404_step "08" "Enabling Required APIs"

channel404_progress "Enabling Cloud Run API" \
  gcloud services enable run.googleapis.com --quiet

channel404_progress "Enabling Cloud Build API" \
  gcloud services enable cloudbuild.googleapis.com --quiet

# =================== Step 9: Deployment ===================
channel404_section "DEPLOYMENT PROCESS"
channel404_step "09" "Deploying VLESS WS Service"

channel404_progress "Deploying ${SERVICE} to ${REGION}" \
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
    --quiet

# =================== Result ===================
channel404_section "DEPLOYMENT RESULTS"
channel404_step "10" "Service Information"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')" || true
CANONICAL_HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
URL_CANONICAL="https://${CANONICAL_HOST}"

printf "\n"
channel404_divider
channel404_box "${C_404_SUCCESS}🚀 DEPLOYMENT SUCCESSFUL${RESET}"
channel404_box ""
channel404_box "${C_404_SECONDARY}🌐 Service URL:${RESET}"
channel404_box "  ${C_404_ACCENT}${URL_CANONICAL}${RESET}"
channel404_box ""
channel404_box "${C_404_SECONDARY}⚡ Protocol:${RESET} VLESS WebSocket (WS)"
channel404_box "${C_404_SECONDARY}🏷️  Region:${RESET} ${REGION}"
channel404_box "${C_404_SECONDARY}💾 Resources:${RESET} ${CPU} vCPU / ${MEMORY}"
channel404_divider_end

# =================== VLESS Configuration ===================
VLESS_UUID="ba0e3984-ccc9-48a3-8074-b2f507f41ce8"
VLESS_URI="vless://${VLESS_UUID}@vpn.googleapis.com:443?path=%2F%40nkka404&security=tls&encryption=none&host=${CANONICAL_HOST}&type=ws#CHANNEL-404-VLESS-WS"

printf "\n${C_404_SECONDARY}🔑 VLESS Configuration URI:${RESET}\n"
channel404_divider
channel404_box "${VLESS_URI}"
channel404_divider_end

# =================== Telegram Notification ===================
json_escape(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

tg_send(){
  local text="$1"
  if [[ -z "${TELEGRAM_TOKEN:-}" || ${#CHAT_ID_ARR[@]} -eq 0 ]]; then return 0; fi
  
  local MSG=$(cat <<EOF
✅ <b>CHANNEL 404 - VLESS WS Deployed Successfully</b>
━━━━━━━━━━━━━━━━━━
<blockquote>🚀 <b>Service:</b> ${SERVICE}
🌍 <b>Region:</b> ${REGION}
⚡ <b>Protocol:</b> VLESS WebSocket
💾 <b>Resources:</b> ${CPU} vCPU / ${MEMORY}</blockquote>
🔗 <b>Service URL:</b>
<code>${URL_CANONICAL}</code>

🔑 <b>VLESS Configuration:</b>
<pre><code>${VLESS_URI}</code></pre>

<blockquote>🕒 <b>Deployed:</b> ${START_LOCAL}
⏳ <b>Valid Until:</b> ${END_LOCAL}</blockquote>
━━━━━━━━━━━━━━━━━━
#CloudRun #VLESS #Channel404
EOF
  )
  
  for _cid in "${CHAT_ID_ARR[@]}"; do
    curl -s -S -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
      -d "chat_id=${_cid}" \
      --data-urlencode "text=${MSG}" \
      -d "parse_mode=HTML" >>"$LOG_FILE" 2>&1
  done
}

channel404_section "NOTIFICATION"
channel404_step "11" "Sending Telegram Notification"

if [[ -n "${TELEGRAM_TOKEN:-}" && ${#CHAT_ID_ARR[@]} -gt 0 ]]; then
  channel404_progress "Sending Telegram notification" tg_send "${MSG}"
  channel404_status "✅" "Telegram notification sent"
else
  channel404_status "⚠️" "Telegram notification skipped"
fi

# =================== Final Output ===================
printf "\n"
channel404_divider
channel404_box "${C_404_SUCCESS}✨ DEPLOYMENT COMPLETE ✨${RESET}"
channel404_box ""
channel404_box "${C_404_SECONDARY}📊 Summary:${RESET}"
channel404_box "• VLESS WebSocket service deployed"
channel404_box "• Warm instance enabled (min=1)"
channel404_box "• Cold start prevention active"
channel404_box "• Auto-scaling configured"
channel404_box ""
channel404_box "${C_404_WARNING}💡 Tip:${RESET} Use with CDN for better performance"
channel404_divider_end

printf "\n${C_404_GREY}📄 Log file: ${LOG_FILE}${RESET}\n"
printf "${C_404_GREY}🔧 Support: @premium_channel_404${RESET}\n\n"
