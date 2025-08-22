#!/bin/bash
# =============================================
# Full Blueprint Installer for Pterodactyl Panel
# Author: InfinityForge (joy)
# =============================================

# Exit immediately if a command exits with a non-zero status
set -e

# ===== CONFIG =====
PANEL_PATH="/var/www/pterodactyl"        # Pterodactyl panel path
BLUEPRINT_RC="$PANEL_PATH/.blueprintrc"
LOG_FILE="/var/log/blueprint_install.log"

# ===== FUNCTIONS =====
log() {
    echo -e "[`date '+%Y-%m-%d %H:%M:%S'`] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "[`date '+%Y-%m-%d %H:%M:%S'`] ERROR: $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "$1 is required but not installed. Exiting."
}

# ===== START INSTALLATION =====
log "Starting Blueprint installer for Pterodactyl..."

# ===== UPDATE SYSTEM & INSTALL BASIC DEPENDENCIES =====
log "Updating system and installing dependencies..."
apt update -y || error_exit "Failed to update package lists."
apt install -y ca-certificates curl gnupg zip unzip git wget || error_exit "Failed to install dependencies."

# ===== INSTALL NODE.JS 20 =====
log "Installing Node.js 20..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg || error_exit "Failed to import NodeSource GPG key."
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt update -y || error_exit "Failed to update package lists after adding Node.js repository."
apt install -y nodejs || error_exit "Failed to install Node.js 20."

check_command node
log "Node.js version: $(node -v)"

# ===== INSTALL YARN =====
log "Installing Yarn globally..."
npm i -g yarn || error_exit "Failed to install Yarn."
check_command yarn
log "Yarn version: $(yarn -v)"

# ===== INSTALL PTERODACTYL PANEL DEPENDENCIES =====
if [ -d "$PANEL_PATH" ]; then
    log "Installing Pterodactyl panel dependencies via Yarn..."
    cd "$PANEL_PATH"
    yarn || error_exit "Failed to install Pterodactyl dependencies."
else
    error_exit "Pterodactyl path $PANEL_PATH does not exist."
fi

# ===== DOWNLOAD BLUEPRINT RELEASE =====
log "Downloading latest Blueprint release..."
LATEST_URL=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)
if [ -z "$LATEST_URL" ]; then
    error_exit "Failed to fetch Blueprint latest release URL."
fi

wget "$LATEST_URL" -O release.zip || error_exit "Failed to download Blueprint release."

# ===== EXTRACT BLUEPRINT =====
log "Extracting Blueprint release..."
unzip -o release.zip -d "$PANEL_PATH" || error_exit "Failed to extract Blueprint release."
rm -f release.zip

# ===== CONFIGURE .blueprintrc =====
log "Creating .blueprintrc configuration..."
cat > "$BLUEPRINT_RC" <<EOL
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOL

# ===== SET PERMISSIONS =====
log "Setting ownership and permissions..."
chown -R www-data:www-data "$PANEL_PATH" || error_exit "Failed to set permissions."

# ===== RUN BLUEPRINT INSTALLER =====
log "Running Blueprint installer..."
export APP_BASE="$PANEL_PATH"
chmod +x "$PANEL_PATH/blueprint.sh"
cd "$PANEL_PATH"
./blueprint.sh install || error_exit "Blueprint installation failed."

# ===== RUN BLUEPRINT UPGRADE =====
log "Running blueprint -upgrade..."
cp "$PANEL_PATH/blueprint" /usr/local/bin/ 2>/dev/null || log "blueprint binary already exists in /usr/local/bin/"
chmod +x /usr/local/bin/blueprint
blueprint -upgrade || error_exit "Blueprint upgrade failed."

log "Blueprint installation and upgrade completed successfully!"
log "You can now run 'blueprint -help' to check available commands."
