#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Color variables for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print success messages
success_msg() {
    echo -e "${GREEN}=============${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}=============${NC}"
}

# Default values (can be overridden by passing arguments)
ROM_MANIFEST_URL="${1:-https://github.com/LineageOS/android.git}"
ROM_BRANCH="${2:-lineage-18.1}"
DEVICE_NAME="${3:-ASUS_Z01KD_1}"
ROM_NAME="${4:-lineage}"
BUILD_TYPE="${5:-userdebug}"
REMOVE_PREBUILTS="${6:-yes}"  # Accept 'yes' or 'no' to remove prebuilts

# Print starting message
echo -e "${CYAN}Starting ROM build for device: ${DEVICE_NAME}${NC}"
echo -e "${CYAN}ROM: ${ROM_NAME}, Branch: ${ROM_BRANCH}, Build type: ${BUILD_TYPE}${NC}"

# Remove prebuilts directory if specified
if [[ "$REMOVE_PREBUILTS" == "yes" ]]; then
    echo -e "${YELLOW}Removing prebuilts directory...${NC}"
    rm -rf prebuilts
    success_msg "Prebuilts removed successfully!"
else
    echo -e "${YELLOW}Skipping prebuilts removal.${NC}"
    success_msg "Prebuilts removal skipped!"
fi

# Initialize the repo
echo -e "${BLUE}Initializing repo with manifest: ${ROM_MANIFEST_URL} (branch: ${ROM_BRANCH})...${NC}"
repo init -u "$ROM_MANIFEST_URL" -b "$ROM_BRANCH" --git-lfs
success_msg "Repo initialized successfully!"

# Set up local manifests
echo -e "${BLUE}Setting up local manifests...${NC}"
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests
cp scripts/roomservice.xml .repo/local_manifests/
success_msg "Local manifests set up successfully!"

# Sync repositories
if [ -f /opt/crave/resync.sh ]; then
    echo -e "${BLUE}Syncing repositories using crave resync...${NC}"
    /opt/crave/resync.sh
else
    echo -e "${YELLOW}/opt/crave/resync.sh not found. Falling back to traditional repo sync...${NC}"
    repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j"$(nproc --all)"
fi
success_msg "Sync completed successfully!"

# Set up the build environment
echo -e "${BLUE}Configuring build environment...${NC}"
source build/envsetup.sh
lunch "${ROM_NAME}_${DEVICE_NAME}-${BUILD_TYPE}"
success_msg "Build environment configured successfully!"

# Build the ROM
echo -e "${YELLOW}Building the ROM...${NC}"
make -j"$(nproc)" bacon
success_msg "ROM built successfully!"

# Define the path to the built ROM zip file
BUILT_ROM_PATH="out/target/product/${DEVICE_NAME}/${ROM_NAME}*.zip"

# Attempt to pull the built ROM using crave
echo -e "${CYAN}Attempting to pull the built ROM from $BUILT_ROM_PATH...${NC}"
crave pull $BUILT_ROM_PATH

# Check if the pull command succeeded
if [ $? -eq 0 ]; then
    success_msg "ROM pulled successfully!"
else
    echo -e "${RED}=============${NC}"
    echo -e "${RED}Failed to pull the ROM zip file.${NC}"
    echo -e "${RED}=============${NC}"
    exit 1
fi
