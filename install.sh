#!/bin/bash
# Full Blueprint installer for Pterodactyl
# Author: InfinityForge (joy)

set -e

# ===== CONFIG =====
PANEL_PATH="/var/www/pterodactyl"   # আপনার প্যানেল path
BLUEPRINT_RC="$PANEL_PATH/.blueprintrc"

# ===== INSTALL DEPENDENCIES =====
echo "==> Updating system and installing required packages..."
apt update
apt install -y ca-certificates curl gnupg zip unzip git wget

# ===== NODE.JS 20 INSTALL =====
echo "==> Installing Node.js 20..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt update
apt install -y nodejs

# ===== YARN INSTALL =====
echo "==> Installing Yarn..."
npm i -g yarn

# ===== PANEL DEPENDENCIES =====
echo "==> Installing Pterodactyl dependencies..."
cd $PANEL_PATH
yarn

# ===== DOWNLOAD BLUEPRINT RELEASE =====
echo "==> Downloading latest Blueprint release..."
wget "$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep 'browser_download_url' | cut -d '"' -f 4)" -O release.zip

# ===== EXTRACT RELEASE =====
echo "==> Extracting release..."
unzip -o release.zip -d $PANEL_PATH
rm -f release.zip

# ===== CONFIGURE .blueprintrc =====
echo "==> Creating .blueprintrc..."
cat > $BLUEPRINT_RC <<EOL
WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";
EOL

# ===== SET PERMISSIONS =====
echo "==> Setting permissions..."
chown -R www-data:www-data $PANEL_PATH

# ===== RUN BLUEPRINT INSTALLER =====
echo "==> Setting APP_BASE and running blueprint.sh..."
export APP_BASE="$PANEL_PATH"
chmod +x $PANEL_PATH/blueprint.sh
cd $PANEL_PATH
./blueprint.sh install

# ===== RUN BLUEPRINT UPGRADE =====
echo "==> Running blueprint -upgrade..."
cp $PANEL_PATH/blueprint /usr/local/bin/ || true
chmod +x /usr/local/bin/blueprint
blueprint -upgrade

echo "==> Blueprint installation and upgrade complete!"
echo "Run 'blueprint -help' to check commands."
