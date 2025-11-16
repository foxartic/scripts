#!/bin/bash

# ==========================================================
#                ANDROID ROM BUILD SCRIPT
#        Clean, Beautified, No Colors, No Emojis
#   Includes:
#     - Automatic Java 8 setup (persistent)
#     - Automatic Bison / Flex prebuilts fix
#     - Crave-safe sync
#     - Oreo-ready environment
# ==========================================================

set -e

# ---------------------- LOG FUNCTIONS ----------------------
info()    { echo "[INFO]    $1"; }
success() { echo "[SUCCESS] $1"; }
warn()    { echo "[WARNING] $1"; }
error()   { echo "[ERROR]   $1"; }
section() {
    echo ""
    echo "=========================================================="
    echo "  $1"
    echo "=========================================================="
    echo ""
}

# ---------------------- INPUT ARGUMENTS ---------------------
ROM_MANIFEST_URL="${1:-https://github.com/LineageOS/android.git}"
ROM_BRANCH="${2:-lineage-15.1}"
DEVICE="${3:-Z01KD_1}"
ROM="${4:-lineage}"
BUILD_TYPE="${5:-userdebug}"
REMOVE_PREBUILTS="${6:-yes}"

# ==========================================================
section "Java 8 Environment Setup"
# ==========================================================

JAVA_VER=$(java -version 2>&1 | head -n1 | grep '1.8')

if [[ -z "$JAVA_VER" ]]; then
    warn "Java 8 not detected. Installing temporary Java 8..."

    mkdir -p $HOME/.java8
    cd $HOME/.java8

    if [[ ! -d "$HOME/.java8/jdk8u412" ]]; then
        info "Downloading BellSoft Java 8..."
        wget -q https://download.bell-sw.com/java/8u412+9/bellsoft-jdk8u412+9-linux-x64.tar.gz
        tar -xf bellsoft-jdk8u412+9-linux-x64.tar.gz
    fi

    export JAVA_HOME="$HOME/.java8/jdk8u412"
    export PATH="$JAVA_HOME/bin:$PATH"

    success "Java 8 activated."
else
    success "Java 8 already installed."
fi

java -version
javac -version

# ==========================================================
section "ROM Build Initialization"
# ==========================================================

info "Device        : $DEVICE"
info "ROM Name      : $ROM"
info "Manifest URL  : $ROM_MANIFEST_URL"
info "Branch        : $ROM_BRANCH"
info "Build Type    : $BUILD_TYPE"

# ==========================================================
section "Prebuilts Cleanup"
# ==========================================================

if [[ "$REMOVE_PREBUILTS" == "yes" ]]; then
    warn "Removing existing prebuilts/ directory..."
    rm -rf prebuilts
    success "Prebuilts directory removed."
else
    info "Prebuilts removal skipped."
fi

# ==========================================================
section "Repo Initialization"
# ==========================================================

repo init -u "$ROM_MANIFEST_URL" -b "$ROM_BRANCH" --git-lfs
success "Repo initialized."

# ==========================================================
section "Local Manifests Setup"
# ==========================================================

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

if cp scripts/roomservice.xml .repo/local_manifests/; then
    success "roomservice.xml applied."
else
    error "roomservice.xml not found in scripts/. Exiting."
    exit 1
fi

# ==========================================================
section "Fixing Missing Bison & Flex (Oreo Prebuilts)"
# ==========================================================

BISON_DIR="prebuilts/misc/linux-x86/bison"
FLEX_DIR="prebuilts/misc/linux-x86/flex"

mkdir -p $BISON_DIR
mkdir -p $FLEX_DIR

if [[ ! -f "$BISON_DIR/bison" ]]; then
    warn "Bison prebuilts missing. Installing..."
    wget -q https://archive.org/download/aosp_prebuilts/bison-2.7-linux-x86.tar.gz
    tar -xf bison-2.7-linux-x86.tar.gz -C $BISON_DIR --strip-components=1
    success "Bison installed."
else
    success "Bison already present."
fi

if [[ ! -f "$FLEX_DIR/flex" ]]; then
    warn "Flex prebuilts missing. Installing..."
    wget -q https://archive.org/download/aosp_prebuilts/flex-2.5.39-linux-x86.tar.gz
    tar -xf flex-2.5.39-linux-x86.tar.gz -C $FLEX_DIR --strip-components=1
    success "Flex installed."
else
    success "Flex already present."
fi

# ==========================================================
section "Syncing Source"
# ==========================================================

if [[ -f /opt/crave/resync.sh ]]; then
    info "Using Crave's optimized resync.sh..."
    /opt/crave/resync.sh
else
    warn "resync.sh not found. Using standard repo sync."
    repo sync -c --no-clone-bundle --optimized-fetch --prune --force-sync -j"$(nproc)"
fi

success "Source sync completed."

# ==========================================================
section "Build Environment Setup"
# ==========================================================

source build/envsetup.sh
lunch "${ROM}_${DEVICE}-${BUILD_TYPE}"

success "Build environment configured."

# ==========================================================
section "Building ROM"
# ==========================================================

info "Starting the build. This may take a long time."

if make -j"$(nproc)" bacon; then
    success "ROM built successfully."
else
    error "Build failed. Exiting."
    exit 1
fi

# ==========================================================
section "Pulling Output ZIP"
# ==========================================================

ZIP_PATH="out/target/product/${DEVICE}/${ROM}*.zip"

if crave pull $ZIP_PATH; then
    success "ROM ZIP pulled successfully."
else
    error "Could not locate ROM ZIP."
    exit 1
fi

success "Build process completed."
