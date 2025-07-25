#!/bin/bash

# === Color Codes ===
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

# === Configuration ===
BLACKLIST_URL="https://raw.githubusercontent.com/smyazdanp/autopurify/main/AutoPurify-Blocklist.txt"
HOSTS_FILE="/etc/hosts"
BACKUP_FILE="/etc/hosts.backup"
TEMP_FILE="/tmp/autopurify-temp"
BEGIN_TAG="# BEGIN AutoPurify"
END_TAG="# END AutoPurify"

echo -e "${YELLOW}=== AutoPurify Installer ===${RESET}"

# Backup the original /etc/hosts file (only once)
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "🔒 Creating backup of ${HOSTS_FILE}..."
    sudo cp "$HOSTS_FILE" "$BACKUP_FILE"
else
    echo -e "📁 Backup already exists at ${BACKUP_FILE}."
fi

# Download the latest blocklist file
echo -e "📥 Downloading latest blocklist..."
curl -s -o "$TEMP_FILE" "$BLACKLIST_URL"
if [ ! -s "$TEMP_FILE" ]; then
    echo -e "${RED}❌ Failed to download blocklist.${RESET}"
    exit 1
fi

# Remove previous AutoPurify block section if exists
sudo sed -i "/$BEGIN_TAG/,/$END_TAG/d" "$HOSTS_FILE"

# Append new blocklist section with tag markers
echo -e "⚙️  Updating ${HOSTS_FILE}..."
{
    echo "$BEGIN_TAG"
    cat "$TEMP_FILE"
    echo "$END_TAG"
} | sudo tee -a "$HOSTS_FILE" > /dev/null

# Count number of blocked domains
BLOCKED_COUNT=$(grep -E '^0\.0\.0\.0\s+' "$TEMP_FILE" | wc -l)

echo -e "${GREEN}✅ Blocklist updated. Total domains blocked: $BLOCKED_COUNT${RESET}"

# Show current block status
echo
echo -e "${YELLOW}🔍 Current block status:${RESET}"
if grep -q "$BEGIN_TAG" "$HOSTS_FILE"; then
    CURRENT=$(grep -E '^0\.0\.0\.0\s+' "$HOSTS_FILE" | wc -l)
    echo -e "${GREEN}✔ Hosts file is already protected by AutoPurify.${RESET}"
    echo -e "${GREEN}✔ Domains currently blocked: $CURRENT${RESET}"
else
    echo -e "${RED}✖ No AutoPurify entries found.${RESET}"
fi

# Prompt for enabling weekly auto-update
echo
read -p "Do you want to enable automatic weekly updates? (y/n): " enable_cron

if [[ "$enable_cron" == "y" || "$enable_cron" == "Y" ]]; then
    CRON_CMD="@weekly curl -s $BLACKLIST_URL | sudo sed -i '/$BEGIN_TAG/,/$END_TAG/d' $HOSTS_FILE && echo \"$BEGIN_TAG\" | sudo tee -a $HOSTS_FILE > /dev/null && curl -s $BLACKLIST_URL | sudo tee -a $HOSTS_FILE > /dev/null && echo \"$END_TAG\" | sudo tee -a $HOSTS_FILE > /dev/null # autopurify"
    
    # Remove any existing AutoPurify crontab entry
    (crontab -l 2>/dev/null | grep -v autopurify ; echo "$CRON_CMD") | crontab -
    
    echo -e "${GREEN}🔁 Auto-update enabled via cron.${RESET}"
else
    echo -e "${YELLOW}⏭ Auto-update skipped.${RESET}"
fi

# Final notice
echo
echo -e "${GREEN}🧹 Done. You can restore your original hosts file anytime using:${RESET}"
echo -e "${YELLOW}    sudo cp $BACKUP_FILE $HOSTS_FILE${RESET}"
