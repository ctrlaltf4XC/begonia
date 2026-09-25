#!/bin/bash
# DYNAMIC PBRP BUILD - BEGONIA
# Complete script for dynamic recovery image build

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "🎯=== DYNAMIC PBRP BUILD FOR BEGONIA ==="
echo "Building dynamic recovery image optimized for Android 11+ ROMs..."

# Configuration
export PBRP_VARIANT="${PBRP_VARIANT:-dynamic}"
export PBRP_ENABLE_CRYPTO="${PBRP_ENABLE_CRYPTO:-true}"
if [ "$PBRP_ENABLE_CRYPTO" != true ]; then
    echo "ERROR: the dynamic build requires PBRP_ENABLE_CRYPTO=true" >&2
    exit 2
fi
export ALLOW_MISSING_DEPENDENCIES=true

# Verification - Check workspace preparation
echo "🔍 Verification - Checking workspace preparation..."
echo "✓ Checking current fixes..."
git log --oneline -3

echo ""
echo "✓ Checking fstab variants..."
ls pbrp_device_tree/variants/

echo ""
echo "✓ Verifying optional crypto shim..."
test -f pbrp_device_tree/libshim_beanpod/Android.mk
echo "✅ Workspace is fully prepared for dynamic build!"

# Create build directory
mkdir -p dynamic_build
PBRP_ROOT="$REPO_ROOT/dynamic_build"
cd "$PBRP_ROOT"

# Initialize PBRP (assuming repo is in PATH)
echo "Initializing PBRP..."
repo init -u https://github.com/PitchBlackRecoveryProject/manifest_pb -b android-12.1 --depth=1
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# Setup device tree (using workspace fixes)
echo "Setting up device tree..."
cd "$PBRP_ROOT"
rm -rf device/xiaomi/begonia
mkdir -p device/xiaomi
cp -rp "$REPO_ROOT/pbrp_device_tree" device/xiaomi/begonia

# Select dynamic fstab
mkdir -p device/xiaomi/begonia/recovery/root/system/etc
cp pbrp_device_tree/variants/recovery.fstab.$PBRP_VARIANT \
   device/xiaomi/begonia/recovery/root/system/etc/recovery.fstab

# Fetch dependencies
cd device/xiaomi/begonia
./fetch-decryption-blobs.sh

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
