#!/bin/bash

# =================================================================
# OpenWrt Build Automation Script for Docker Environment
# =================================================================

# Exit on any error
set -e

# --- Configuration ---
REPO_URL="https://github.com/lkiuyu/immortalwrt"
REPO_BRANCH="master"
CONFIG_FILE="/workspace/configs/jz02.config"
DIY_P1_SH="/workspace/scripts/diy-part1.sh"
DIY_P2_SH="/workspace/scripts/diy-part2.sh"
SOURCE_DIR="/workspace/source"
DL_DIR="/workspace/dl"
RELEASE_DIR="/workspace/release"
SSH_ACTION="${1:-false}" # First argument to the script, defaults to false

# --- Build Process ---

# 1. Clone source code if it doesn't exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo ">>> Cloning source code..."
    git clone --depth 1 "$REPO_URL" -b "$REPO_BRANCH" "$SOURCE_DIR"
else
    echo ">>> Source directory exists, skipping clone. Pulling latest changes..."
    cd "$SOURCE_DIR"
    git pull
fi

cd "$SOURCE_DIR"

# 2. Run custom script part 1 (before feeds)
if [ -f "$DIY_P1_SH" ]; then
    echo ">>> Running diy-part1.sh..."
    chmod +x "$DIY_P1_SH"
    "$DIY_P1_SH"
fi

# 3. Update and install feeds
echo ">>> Updating and installing feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 4. Load configuration and run custom script part 2
echo ">>> Loading configuration..."
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" ./.config
else
    echo "::error:: Configuration file not found at $CONFIG_FILE!"
    exit 1
fi

if [ -f "$DIY_P2_SH" ]; then
    echo ">>> Running diy-part2.sh..."
    chmod +x "$DIY_P2_SH"
    "$DIY_P2_SH"
fi

# 5. Standardize config and download packages
echo ">>> Standardizing configuration and downloading packages..."
# The ultimate fix for interactive prompts
yes '' | make oldconfig
make download -j$(nproc)

# 6. Compile the firmware
echo ">>> Compiling firmware... This may take a long time."
# Use the robust compile command
make -j$(nproc) || make -j1 V=s

echo ">>> Compilation finished."

# 7. Organize release files
echo ">>> Organizing release files..."
mkdir -p "$RELEASE_DIR"
FIRMWARE_DIR="$SOURCE_DIR/bin/targets/msm89xx/msm8916"
if [ -d "$FIRMWARE_DIR" ]; then
    cp -r ${FIRMWARE_DIR}/* "$RELEASE_DIR/"
    echo ">>> Firmware files copied to $RELEASE_DIR"
else
    echo "::warning:: Firmware directory not found after successful compilation."
fi

# 8. Trigger SSH session if requested
if [ "$SSH_ACTION" = "true" ]; then
    echo ">>> Starting tmate SSH session for debugging..."
    tmate -S /tmp/tmate.sock new-session -d
    tmate -S /tmp/tmate.sock wait tmate-ready
    tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}'
    sleep infinity
fi

echo ">>> Build process completed successfully!"
