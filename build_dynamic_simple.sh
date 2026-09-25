#!/bin/bash
# DYNAMIC PBRP BUILD SCRIPT - BEGONIA
# Simplified version for quick execution

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "🎯=== DYNAMIC PBRP BUILD FOR BEGONIA ==="
echo "Building dynamic recovery image..."

# Configuration
# PBRP_VARIANT selects the fstab: safe | static | dynamic
#   safe    - no-crypto startup image (use this to diagnose the splash hang)
#   static  - by-name system/vendor image for the explicit crypto build
#   dynamic - logical/super image for the explicit crypto build
# PBRP_ENABLE_CRYPTO=true enables the vendor MicroTrust keymaster stack.
export PBRP_VARIANT="${PBRP_VARIANT:-safe}"
export PBRP_ENABLE_CRYPTO="${PBRP_ENABLE_CRYPTO:-false}"
export ALLOW_MISSING_DEPENDENCIES=true
if [ "$PBRP_ENABLE_CRYPTO" != true ] && [ "$PBRP_VARIANT" != safe ]; then
    echo "ERROR: no-crypto builds support only PBRP_VARIANT=safe" >&2
    exit 2
fi
if [ "$PBRP_ENABLE_CRYPTO" = true ] && [ "$PBRP_VARIANT" = safe ]; then
    echo "ERROR: crypto builds require PBRP_VARIANT=static or dynamic" >&2
    exit 2
fi
echo "variant=$PBRP_VARIANT crypto=$PBRP_ENABLE_CRYPTO"

# Verification
echo "✓ Checking fixes..."
git log --oneline -1
echo "✓ Checking fstab variants..."
ls pbrp_device_tree/variants/

# Create build directory
mkdir -p dynamic_build
PBRP_ROOT="$REPO_ROOT/dynamic_build"
cd "$PBRP_ROOT"

# Initialize PBRP (assuming repo is in PATH)
echo "Initializing PBRP..."
repo init -u https://github.com/PitchBlackRecoveryProject/manifest_pb -b android-12.1 --depth=1
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# Setup device tree (using fixed version from workspace)
echo "Setting up device tree..."
cd "$PBRP_ROOT"
rm -rf device/xiaomi/begonia
mkdir -p device/xiaomi
cp -rp "$REPO_ROOT/pbrp_device_tree" device/xiaomi/begonia

# Select dynamic fstab
mkdir -p device/xiaomi/begonia/recovery/root/system/etc
cp pbrp_device_tree/variants/recovery.fstab.$PBRP_VARIANT \
   device/xiaomi/begonia/recovery/root/system/etc/recovery.fstab

# Fetch dependencies only for the explicit crypto build
cd device/xiaomi/begonia
if [ "$PBRP_ENABLE_CRYPTO" = true ]; then
    ./fetch-decryption-blobs.sh
else
    echo "Skipping TEE blobs for no-crypto build"
fi

# Apply patches
cd "$PBRP_ROOT"
ANDROID_BUILD_TOP="$PBRP_ROOT" ./device/xiaomi/begonia/patches/apply-patches.sh

# Setup build
source build/envsetup.sh
lunch pb_begonia-eng

# Build
echo "Starting build (this will take 4-6 hours)..."
mka recoveryimage

echo "✅ Build completed!"
echo "Output: out/target/product/begonia/recovery.img"
