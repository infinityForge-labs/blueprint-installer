#!/usr/bin/env bash
# =============================================
# Full Blueprint Installer for Pterodactyl Panel
# Colorful + Animated Edition ✨
# Author: InfinityForge (joy)
# =============================================

set -Eeuo pipefail

# ===== CONFIG =====
PANEL_PATH="/var/www/pterodactyl"
BLUEPRINT_RC="$PANEL_PATH/.blueprintrc"
LOG_FILE="/var/log/blueprint_install.log"
export DEBIAN_FRONTEND=noninteractive

# ===== COLORS =====
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
  BOLD="$(tput bold)"; RESET="$(tput sgr0)"
  RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"; BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"; CYAN="$(tput setaf 6)"
else
  BOLD=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""
fi

# ===== UI: BANNER & SPINNER =====
banner() {
  clear || true
  cat <<'ASCII'
   ███████╗██╗   ██╗██████╗ ██╗     ██████╗ ██████╗ ██╗   ██╗██████╗ ████████╗
   ██╔════╝██║   ██║██╔══██╗██║     ██╔══██╗██╔══██╗██║   ██║██╔══██╗╚══██╔══╝
   █████╗  ██║   ██║██████╔╝██║     ██████╔╝██████╔╝██║   ██║██████╔╝   ██║
   ██╔══╝  ██║   ██║██╔══██╗██║     ██╔═══╝ ██╔══██╗██║   ██║██╔══██╗   ██║
   ██║     ╚██████╔╝██║  ██║███████╗██║     ██║  ██║╚██████╔╝██║  ██║   ██║
   ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
ASCII
  echo -e "${BOLD}${CYAN}     Blueprint Installer for Pterodactyl • InfinityForge (joy)${RESET}\n"
}

spin_pid=""
start_spinner() {
  local msg="$1"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  printf "%b" "${BLUE}${msg} ${RESET}"
  (
    i=0
    while :; do
      printf "\r%b" "${BLUE}${msg} ${frames[$((i%10))]}${RESET}"
      i=$((i+1))
      sleep 0.08
    done
  ) &
  spin_pid=$!
  disown "$spin_pid" 2>/dev/null || true
}

stop_spinner_ok() {
  if [[ -n "${spin_pid:-}" ]]; then kill "$spin_pid" 2>/dev/null || true; fi
  printf "\r%b\n" "${GREEN}✔ Done${RESET}"
  spin_pid=""
}
stop_spinner_fail() {
  if [[ -n "${spin_pid:-}" ]]; then kill "$spin_pid" 2>/dev/null || true; fi
  printf "\r%b\n" "${RED}✘ Failed${RESET}"
  spin_pid=""
}

# ===== LOGGING =====
log()   { echo -e "[$(date '+%F %T')] ${GREEN}$*${RESET}" | tee -a "$LOG_FILE"; }
warn()  { echo -e "[$(date '+%F %T')] ${YELLOW}WARNING:${RESET} $*" | tee -a "$LOG_FILE"; }
err()   { echo -e "[$(date '+%F %T')] ${RED}ERROR:${RESET} $*" | tee -a "$LOG_FILE" >&2; }

trap 'err "Unexpected error on line $LINENO"; stop_spinner_fail; exit 1' ERR

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Please run as root (sudo)."
    exit 1
  fi
}

run_step() {
  # Usage: run_step "Message" cmd arg...
  local msg="$1"; shift
  start_spinner "$msg"
  {
    "$@" >>"$LOG_FILE" 2>&1
  } && { stop_spinner_ok; } || { stop_spinner_fail; err "$msg (see $LOG_FILE)"; exit 1; }
}

# ===== PRECHECKS =====
require_root
mkdir -p "$(dirname "$LOG_FILE")"
banner
log "Log file: $LOG_FILE"
log "Panel path: $PANEL_PATH"

[[ -d "$PANEL_PATH" ]] || { err "PANEL_PATH not found: $PANEL_PATH"; exit 1; }

# ===== STEPS =====
run_step "Updating APT index…"                apt-get update -y -o=Dpkg::Use-Pty=0
run_step "Installing base packages…"          apt-get install -y ca-certificates curl gnupg zip unzip git wget jq build-essential

# Node.js 20
run_step "Adding NodeSource (Node.js 20) key…" bash -c 'mkdir -p /etc/apt/keyrings && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg'
run_step "Adding NodeSource repo…"             bash -c 'echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list'
run_step "Updating after NodeSource add…"      apt-get update -y -o=Dpkg::Use-Pty=0
run_step "Installing Node.js 20…"              apt-get install -y nodejs

# Yarn
run_step "Installing Yarn (global)…"           npm i -g yarn

# Panel deps
run_step "Installing panel JS deps (yarn)…"    bash -c "cd '$PANEL_PATH' && yarn --ignore-optional"

# Download Blueprint latest
LATEST_URL="$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4 | head -n1 || true)"
if [[ -z "$LATEST_URL" ]]; then
  warn "Could not resolve latest Blueprint release from GitHub API; continuing (maybe already present?)"
else
  run_step "Downloading Blueprint release…"     bash -c "cd '$PANEL_PATH' && wget -q '$LATEST_URL' -O release.zip"
  run_step "Extracting Blueprint…"              bash -c "unzip -o '$PANEL_PATH/release.zip' -d '$PANEL_PATH' && rm -f '$PANEL_PATH/release.zip'"
fi

# .blueprintrc
run_step "Writing .blueprintrc…"               bash -c "cat >'$BLUEPRINT_RC' <<'EOL'
WEBUSER=\"www-data\";
OWNERSHIP=\"www-data:www-data\";
USERSHELL=\"/bin/bash\";
EOL"

# Permissions
run_step "Applying ownership to panel…"         chown -R www-data:www-data "$PANEL_PATH"

# Symlink /app → PANEL_PATH (Blueprint expects /app)
run_step "Linking /app to panel path…"         bash -c '[[ -L /app || -d /app ]] && rm -rf /app || true; ln -s "'"$PANEL_PATH"'" /app'

# Fix Browserslist warning & build assets
run_step "Upgrading browserslist/caniuse-lite…" bash -c "cd '$PANEL_PATH' && yarn upgrade caniuse-lite browserslist"
run_step "Updating browserslist DB…"            bash -c "cd '$PANEL_PATH' && npx --yes update-browserslist-db@latest"
run_step "Building production assets…"          bash -c "cd '$PANEL_PATH' && yarn build:production"

# Run Blueprint install
run_step "Marking blueprint.sh executable…"    chmod +x "$PANEL_PATH/blueprint.sh"
export APP_BASE="$PANEL_PATH"
run_step "Running Blueprint installer…"        bash -c "cd '$PANEL_PATH' && ./blueprint.sh install"

# Place CLI & upgrade
run_step "Installing blueprint CLI…"           bash -c "cp -f '$PANEL_PATH/blueprint' /usr/local/bin/ 2>/dev/null || true; chmod +x /usr/local/bin/blueprint"
run_step "Running blueprint upgrade…"          blueprint -upgrade

# ===== FINISH =====
echo -e "\n${GREEN}${BOLD}All done!${RESET} 🎉"
echo -e "${CYAN}• Log file:${RESET} $LOG_FILE"
echo -e "${CYAN}• Try:${RESET} ${BOLD}blueprint -help${RESET}\n"

