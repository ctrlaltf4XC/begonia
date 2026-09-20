#!/bin/bash
# DYNAMIC PBRP BUILD - BEGONIA
# Complete script for dynamic recovery image build

set -euo pipefail

echo "🎯=== DYNAMIC PBRP BUILD FOR BEGONIA ==="
echo "Building dynamic recovery image optimized for Android 11+ ROMs..."

# Configuration
export INPUT_VARIANT=dynamic
export ALLOW_MISSING_DEPENDENCIES=true

# Verification - Check workspace preparation
echo "🔍 Verification - Checking workspace preparation..."
echo "✓ Checking current fixes..."
git log --oneline -3

echo ""
echo "✓ Checking fstab variants..."
ls pbrp_device_tree/variants/

echo ""
echo "✓ Verifying libshim_beanpod fix..."
grep -n "key_data = keymaster::KeymasterKeyBlob" pbrp_device_tree/libshim_beanpod/libshim_beanpod.cpp
echo "✅ Workspace is fully prepared for dynamic build!"

# Create build directory
mkdir -p dynamic_build
cd dynamic_build

# Initialize PBRP (assuming repo is in PATH)
echo "Initializing PBRP..."
repo init -u https://github.com/PitchBlackRecoveryProject/manifest_pb -b android-12.1 --depth=1
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# Setup device tree (using workspace fixes)
echo "Setting up device tree..."
cd /workspaces/begonia
rm -rf device/xiaomi/begonia
mkdir -p device/xiaomi
cp -rp pbrp_device_tree device/xiaomi/begonia
rm -rf device/xiaomi/begonia/libshim_beanpod

# Select dynamic fstab
mkdir -p device/xiaomi/begonia/recovery/root/system/etc
cp pbrp_device_tree/variants/recovery.fstab.$INPUT_VARIANT \
   device/xiaomi/begonia/recovery/root/system/etc/recovery.fstab

# Fetch dependencies
cd device/xiaomi/begonia
./fetch-decryption-blobs.sh

# Apply patches
cd ../..
./pbrp_device_tree/patches/apply-patches.sh

# Setup build
source build/envsetup.sh
lunch pb_begonia-eng

# Build
echo "Starting build (this will take 4-6 hours)..."
mka recoveryimage

echo "✅ Build completed!"
echo "Output: out/target/product/begonia/recovery.img"
