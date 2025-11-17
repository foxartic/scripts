#!/bin/bash

# ==========================================================
#                  ANDROID ROM BUILD SCRIPT
#            Clean, Beautified, Crave-Safe Edition
#   Features:
#     - Safe Java 8 setup (no downloads)
#     - Safe Bison & Flex prebuilts fix (no downloads)
#     - Crave-aware PATH setup
#     - Crave optimized sync support
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

# Crave provides Java 8 path: /usr/lib/jvm/java-8-openjdk-amd64
if [[ -n "$CRAVE_BUILD" ]]; then
    info "Crave environment detected. Using Crave's built-in Java 8."
    export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
else
    info "Local environment detected. Using system Java."
    export JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
fi

export PATH="$JAVA_HOME/bin:$PATH"

# Validate Java 8 presence
if ! java -version 2>&1 | grep -q "1.8"; then
    error "Java 8 not detected. Install Java 8 on your system."
    exit 1
fi

success "Java 8 is correctly set."
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
    warn "Removing existing prebuilts directory..."
    rm -rf prebuilts
    success "Prebuilts cleaned."
else
    info "Skipping prebuilts removal."
fi

# ==========================================================
section "Repo Initialization"
# ==========================================================

repo init -u "$ROM_MANIFEST_URL" -b "$ROM_BRANCH" --git-lfs
success "Repo initialized successfully."

# ==========================================================
section "Local Manifests Setup"
# ==========================================================

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

if cp scripts/roomservice.xml .repo/local_manifests/; then
    success "roomservice.xml applied."
else
    error "roomservice.xml missing in scripts/. Exiting."
    exit 1
fi

# ==========================================================
section "Fixing Bison & Flex (Crave-Safe)"
# ==========================================================

SYSTEM_BISON=$(command -v bison || true)
SYSTEM_FLEX=$(command -v flex || true)

if [[ -n "$SYSTEM_BISON" && -n "$SYSTEM_FLEX" ]]; then
    info "System bison and flex detected. Creating prebuilts wrappers."

    mkdir -p prebuilts/misc/linux-x86/bison
    mkdir -p prebuilts/misc/linux-x86/flex

    # Wrapper calling system bison
    cat <<EOT > prebuilts/misc/linux-x86/bison/bison
#!/bin/bash
exec $SYSTEM_BISON "\$@"
EOT

    # Wrapper calling system flex
    cat <<EOT > prebuilts/misc/linux-x86/flex/flex
#!/bin/bash
exec $SYSTEM_FLEX "\$@"
EOT

    chmod +x prebuilts/misc/linux-x86/bison/bison
    chmod +x prebuilts/misc/linux-x86/flex/flex

    success "Bison & Flex wrappers ready."
else
    error "bison or flex missing! Install using:"
    error "sudo apt install bison flex"
    exit 1
fi

# ==========================================================
section "Syncing Source"
# ==========================================================

if [[ -f /opt/crave/resync.sh ]]; then
    info "Using Crave optimized resync..."
    /opt/crave/resync.sh
else
    warn "Crave resync.sh not found. Using standard repo sync."
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
    error "Build failed."
    exit 1
fi

# ==========================================================
section "Pulling Output ZIP"
# ==========================================================

ZIP_PATH="out/target/product/${DEVICE}/${ROM}*.zip"

if crave pull $ZIP_PATH; then
    success "ROM ZIP pulled successfully."
else
    error "Cannot find ROM ZIP."
    exit 1
fi

success "Build process completed."
