#!/bin/bash
# DYNAMIC PBRP BUILD SCRIPT - BEGONIA
# Simplified version for quick execution

set -euo pipefail

echo "🎯=== DYNAMIC PBRP BUILD FOR BEGONIA ==="
echo "Building dynamic recovery image..."

# Configuration
# PBRP_VARIANT selects the fstab: static | dynamic | safe
#   static  - our extended by-name fstab (Android 9/10, safe default 11..16)
#   dynamic - logical/super fstab (required to *install* Android 11..16 ROMs)
#   safe    - exact copy of the known-working begonia tree's fstab (diagnostic)
# BEANPOD_CRYPTO=true relinks the beanpod keymaster stack into recovery; leave
# it false unless you are testing hardware-wrapped-key decryption.
export PBRP_VARIANT="${PBRP_VARIANT:-safe}"
export BEANPOD_CRYPTO="${BEANPOD_CRYPTO:-false}"
export ALLOW_MISSING_DEPENDENCIES=true
echo "variant=$PBRP_VARIANT  beanpod_crypto=$BEANPOD_CRYPTO"

# Verification
echo "✓ Checking fixes..."
git log --oneline -1
echo "✓ Checking fstab variants..."
ls pbrp_device_tree/variants/

# Create build directory
mkdir -p dynamic_build
cd dynamic_build

# Initialize PBRP (assuming repo is in PATH)
echo "Initializing PBRP..."
repo init -u https://github.com/PitchBlackRecoveryProject/manifest_pb -b android-12.1 --depth=1
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# Setup device tree (using fixed version from workspace)
echo "Setting up device tree..."
cd /workspaces/begonia
rm -rf device/xiaomi/begonia
mkdir -p device/xiaomi
cp -rp pbrp_device_tree device/xiaomi/begonia
rm -rf device/xiaomi/begonia/libshim_beanpod

# Select dynamic fstab
mkdir -p device/xiaomi/begonia/recovery/root/system/etc
cp pbrp_device_tree/variants/recovery.fstab.$PBRP_VARIANT \
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
