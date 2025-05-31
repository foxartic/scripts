#!/bin/bash

set -e  # Exit on any error

#===============================================================================
# Android ROM Build Script
# Usage: ./build_rom.sh [manifest_url] [branch] [device] [rom_name] [build_type] [remove_prebuilts]
#===============================================================================

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Build configuration
readonly ROM_MANIFEST_URL="${1:-https://github.com/LineageOS/android.git}"
readonly ROM_BRANCH="${2:-lineage-18.1}"
readonly DEVICE_NAME="${3:-ASUS_Z01KD_1}"
readonly ROM_NAME="${4:-lineage}"
readonly BUILD_TYPE="${5:-userdebug}"
readonly REMOVE_PREBUILTS="${6:-no}"

#===============================================================================
# Helper Functions
#===============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${CYAN}${BOLD}Android ROM Build System${NC}"
    echo -e "${CYAN}========================${NC}\n"
}

print_config() {
    echo -e "${BOLD}Build Configuration:${NC}"
    echo -e "  ROM Manifest: ${ROM_MANIFEST_URL}"
    echo -e "  Branch: ${ROM_BRANCH}"
    echo -e "  Device: ${DEVICE_NAME}"
    echo -e "  ROM Name: ${ROM_NAME}"
    echo -e "  Build Type: ${BUILD_TYPE}"
    echo -e "  Remove Prebuilts: ${REMOVE_PREBUILTS}"
    echo
}

#===============================================================================
# Main Build Process
#===============================================================================

print_header
print_config

# Step 1: Handle prebuilts
log_info "Managing prebuilts directory..."
if [[ "$REMOVE_PREBUILTS" == "yes" ]]; then
    rm -rf prebuilts 2>/dev/null || true
    log_success "Prebuilts directory removed"
else
    log_info "Keeping existing prebuilts directory"
fi

# Step 2: Initialize repository
log_info "Initializing ROM repository..."
if repo init -u "$ROM_MANIFEST_URL" -b "$ROM_BRANCH" --git-lfs --quiet; then
    log_success "Repository initialized"
else
    log_error "Failed to initialize repository"
    exit 1
fi

# Step 3: Setup local manifests
log_info "Setting up local manifests..."
rm -rf .repo/local_manifests 2>/dev/null || true
mkdir -p .repo/local_manifests

if [[ -f "scripts/roomservice.xml" ]]; then
    cp scripts/roomservice.xml .repo/local_manifests/
    log_success "Local manifests configured"
else
    log_warning "roomservice.xml not found, skipping local manifest setup"
fi

# Step 4: Sync source code
log_info "Syncing source code (using $(nproc) jobs)..."
if repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j$(nproc) --quiet; then
    log_success "Source code synchronized"
else
    log_error "Failed to sync source code"
    exit 1
fi

# Step 5: Setup build environment
log_info "Setting up build environment..."
source build/envsetup.sh

log_info "Configuring lunch: ${ROM_NAME}_${DEVICE_NAME}-${BUILD_TYPE}"
if lunch "${ROM_NAME}_${DEVICE_NAME}-${BUILD_TYPE}"; then
    log_success "Build environment ready"
else
    log_error "Failed to configure build environment"
    exit 1
fi

# Step 6: Build ROM
log_info "Starting ROM build (this may take several hours)..."
BUILD_START_TIME=$(date +%s)

if make -j$(nproc) bacon; then
    BUILD_END_TIME=$(date +%s)
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    BUILD_TIME_FORMATTED=$(printf "%02d:%02d:%02d" $((BUILD_DURATION/3600)) $((BUILD_DURATION%3600/60)) $((BUILD_DURATION%60)))
    log_success "ROM built successfully in $BUILD_TIME_FORMATTED"
else
    log_error "ROM build failed"
    exit 1
fi

# Step 7: Retrieve built ROM
log_info "Locating built ROM..."
BUILT_ROM_PATH="out/target/product/${DEVICE_NAME}/${ROM_NAME}*.zip"

if ls $BUILT_ROM_PATH 1> /dev/null 2>&1; then
    ROM_FILE=$(ls $BUILT_ROM_PATH | head -n1)
    ROM_SIZE=$(du -h "$ROM_FILE" | cut -f1)
    log_info "Found ROM: $(basename "$ROM_FILE") (${ROM_SIZE})"
    
    if command -v crave >/dev/null 2>&1; then
        log_info "Pulling ROM with crave..."
        if crave pull "$BUILT_ROM_PATH"; then
            log_success "ROM retrieved via crave"
        else
            log_warning "Crave pull failed, ROM available locally"
        fi
    else
        log_info "ROM available at: $ROM_FILE"
    fi
    
    log_success "Build completed successfully!"
else
    log_error "Built ROM not found at expected location"
    exit 1
fi

echo -e "\n${GREEN}${BOLD}Build Summary:${NC}"
echo -e "${GREEN}✓ ROM: ${ROM_NAME} for ${DEVICE_NAME}${NC}"
echo -e "${GREEN}✓ Build time: ${BUILD_TIME_FORMATTED}${NC}"
if [[ -n "${ROM_FILE:-}" ]]; then
    echo -e "${GREEN}✓ Output: $(basename "$ROM_FILE") (${ROM_SIZE})${NC}"
fi
echo