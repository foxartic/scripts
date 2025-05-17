#!/bin/bash

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Print success messages
success_msg() {
    echo -e "${GREEN}=============${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}=============${NC}"
}

# Default build config
ROM_MANIFEST_URL=${1:-"https://github.com/LineageOS/android.git"}
ROM_BRANCH=${2:-"lineage-18.1"}
DEVICE_NAME=${3:-"ASUS_Z01KD_1"}
ROM_NAME=${4:-"lineage"}
BUILD_TYPE=${5:-"userdebug"}
REMOVE_PREBUILTS=${6:-"no"}
KERNEL_REPO=${7:-"https://github.com/example/kernel_asus_msm8998.git"}
KERNEL_BRANCH=${8:-"lineage-18.1"}

echo -e "${CYAN}Starting build for ${DEVICE_NAME} with ${ROM_NAME} on ${ROM_BRANCH}${NC}"

# Optional: remove prebuilts
if [[ "$REMOVE_PREBUILTS" == "yes" ]]; then
    echo -e "${YELLOW}Removing prebuilts directory...${NC}"
    rm -rf prebuilts
    success_msg "Prebuilts removed!"
else
    echo -e "${YELLOW}Skipping prebuilts removal.${NC}"
    success_msg "Prebuilts removal skipped!"
fi

# Install required cross-compiler
echo -e "${BLUE}Checking for required cross-compiler...${NC}"
if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing gcc-aarch64-linux-gnu...${NC}"
    sudo apt update && sudo apt install -y gcc-aarch64-linux-gnu
    success_msg "Cross-compiler installed"
else
    success_msg "Cross-compiler already available"
fi

# Init repo
echo -e "${BLUE}Initializing ROM repo...${NC}"
repo init -u "$ROM_MANIFEST_URL" -b "$ROM_BRANCH" --git-lfs
success_msg "Repo initialized"

# Local manifests
echo -e "${BLUE}Setting up local manifests...${NC}"
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests
cp scripts/roomservice.xml .repo/local_manifests/
success_msg "Local manifests ready"

# Sync source
echo -e "${BLUE}Syncing source...${NC}"
repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j$(nproc)
success_msg "Source synced"

# Clone and build kernel
echo -e "${CYAN}Cloning kernel source: $KERNEL_REPO ($KERNEL_BRANCH)...${NC}"
git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" kernel/temp
success_msg "Kernel source cloned"

echo -e "${BLUE}Building kernel...${NC}"
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
KERNEL_DIR=$(pwd)/kernel/temp
cd "$KERNEL_DIR"

# Replace this with your defconfig name
make ${DEVICE_NAME}_defconfig || make defconfig

make -j$(nproc)

OUT_IMAGE="arch/arm64/boot/Image.gz-dtb"
if [[ -f "$OUT_IMAGE" ]]; then
    echo -e "${BLUE}Copying kernel to device tree...${NC}"
    cp "$OUT_IMAGE" ../../../device/*/"$DEVICE_NAME"/kernel
    cd ../../..
    success_msg "Kernel built and integrated"
else
    echo -e "${RED}Kernel build failed or output not found: $OUT_IMAGE${NC}"
    exit 1
fi

# Build environment
echo -e "${BLUE}Setting up build environment...${NC}"
source build/envsetup.sh
lunch "${ROM_NAME}_${DEVICE_NAME}-${BUILD_TYPE}"
success_msg "Environment ready"

# Build ROM
echo -e "${YELLOW}Building ROM...${NC}"
make -j$(nproc) bacon
success_msg "ROM built successfully"

# Pull ROM
BUILT_ROM_PATH="out/target/product/${DEVICE_NAME}/${ROM_NAME}*.zip"
echo -e "${CYAN}Trying to pull ROM: $BUILT_ROM_PATH${NC}"
crave pull "$BUILT_ROM_PATH" || { echo -e "${RED}Failed to pull ROM zip.${NC}"; exit 1; }
success_msg "ROM pulled successfully!"
