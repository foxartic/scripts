#!/bin/bash

# =========================
#   Android ROM Build Script
#   Local Machine Version
# =========================

set -e  # Exit on error

# ------------- COLORS -------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ------------- FUNCTIONS -------------
info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
error()   { echo -e "${RED}❌ $1${NC}"; }

section() {
    echo -e "\n${MAGENTA}${BOLD}========== $1 ==========${NC}\n"
}

# ------------- ARGUMENTS & DEFAULTS -------------
ROM_MANIFEST_URL="${1:-https://github.com/LineageOS/android.git}"
ROM_BRANCH="${2:-lineage-15.0}"
DEVICE_NAME="${3:-Z01KD_1}"
ROM_NAME="${4:-lineage}"
BUILD_TYPE="${5:-userdebug}"
REMOVE_PREBUILTS="${6:-no}"  # 'yes' or 'no'

# ------------- START -------------
section "ROM Build Initialization"

info "Device         : ${DEVICE_NAME}"
info "ROM Name       : ${ROM_NAME}"
info "Manifest URL   : ${ROM_MANIFEST_URL}"
info "Branch         : ${ROM_BRANCH}"
info "Build Type     : ${BUILD_TYPE}"
info "Remove Prebuilts: ${REMOVE_PREBUILTS}"

# ------------- REMOVE PREBUILTS -------------
section "Prebuilts Cleanup"
if [[ "$REMOVE_PREBUILTS" == "yes" ]]; then
    warn "Removing prebuilts directory..."
    rm -rf prebuilts
    success "Prebuilts removed!"
else
    info "Skipping prebuilts removal."
    success "Prebuilts removal skipped."
fi

# ------------- REPO INIT -------------
section "Repo Initialization"
if [[ ! -d ".repo" ]]; then
    info "Repo not initialized. Running repo init..."
    repo init -u "$ROM_MANIFEST_URL" -b "$ROM_BRANCH" --git-lfs
    success "Repo initialized!"
else
    info "Repo already initialized. Skipping repo init."
fi

# ------------- LOCAL MANIFESTS -------------
section "Local Manifests Setup"
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests
if cp scripts/roomservice.xml .repo/local_manifests/; then
    success "Local manifests set up!"
else
    error "Failed to copy roomservice.xml!"
    exit 1
fi

# ------------- REPO SYNC -------------
if [[ ! -d "build" ]]; then
    section "Repository Sync"
    info "No build directory found. Running repo sync..."
    repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j"$(nproc --all)"
    success "Repo sync completed!"
else
    info "Sources already synced. Skipping repo sync."
fi

# ------------- BUILD ENVIRONMENT -------------
section "Build Environment Setup"
source build/envsetup.sh
if lunch "${ROM_NAME}_${DEVICE_NAME}-${BUILD_TYPE}"; then
    success "Build environment configured!"
else
    error "Lunch combo failed! Check your device/ROM combo."
    exit 1
fi

# ------------- BUILD ROM -------------
section "ROM Compilation"
info "Building ROM... This may take a while ⏳"
if make -j"$(nproc)" bacon; then
    success "ROM built successfully!"
else
    error "Build failed!"
    exit 1
fi

# ------------- PULL BUILT ROM -------------
section "ROM Retrieval"
BUILT_ROM_PATH="out/target/product/${DEVICE_NAME}/${ROM_NAME}*.zip"
info "Looking for built ROM at: ${BUILT_ROM_PATH}"

if ls $BUILT_ROM_PATH 1> /dev/null 2>&1; then
    success "ROM available at: ${BUILT_ROM_PATH} 🎉"
else
    error "ROM zip file not found!"
    exit 1
fi

section "Build Process Complete"
success "All done! Your ROM is ready."
