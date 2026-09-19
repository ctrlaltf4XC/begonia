#!/usr/bin/env bash
#
# fetch-decryption-blobs.sh
#
# Pulls the MicroTrust "beanpod" TEE decryption stack required to decrypt
# /data on begonia, and installs it into recovery/root/vendor of this tree.
#
# WHY THIS IS NEEDED
# ------------------
# begonia's FBE keys are sealed by the MicroTrust TEE. To unwrap them the
# recovery ramdisk must contain:
#
#   vendor/bin/hw/android.hardware.keymaster@4.0-service.beanpod
#   vendor/bin/hw/android.hardware.gatekeeper@1.0-service
#   vendor/bin/teei_daemon
#   vendor/lib64/hw/gatekeeper.beanpod.so
#   vendor/lib64/hw/kmsetkey.beanpod.so
#   vendor/lib64/libkeymaster4.so (+ support/portable/messages)
#   vendor/thh/ta/*.ta   (Trusted Applications)
#
# These files are proprietary and are therefore NOT committed to this repo.
# This script obtains them from a source that is already publicly redistributed
# for this device.
#
# Usage:
#   cd device/xiaomi/begonia
#   ./fetch-decryption-blobs.sh
#
set -euo pipefail

DEVICE_PATH="$(cd "$(dirname "$0")" && pwd)"
DEST="${DEVICE_PATH}/recovery/root/vendor"

# The Saikrishna1504 PBRP tree for begonia ships the complete, working
# beanpod decrypt stack inside recovery/root/vendor.
SRC_REPO="https://github.com/Saikrishna1504/device_xiaomi_begonia-pbrp.git"
SRC_BRANCH="twrp-12.1"
SRC_SUBDIR="recovery/root/vendor"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Fetching decryption blobs"
echo "    repo:   $SRC_REPO"
echo "    branch: $SRC_BRANCH"

git clone --depth 1 -b "$SRC_BRANCH" "$SRC_REPO" "$TMP/src" >/dev/null 2>&1

SRC="${TMP}/src/${SRC_SUBDIR}"
if [ ! -d "$SRC" ]; then
    echo "ERROR: $SRC_SUBDIR not found in source repo"
    exit 1
fi

echo "==> Installing into recovery/root/vendor"
mkdir -p "$DEST"
cp -a "${SRC}/." "$DEST/"

# Remove anything that does not belong in a recovery ramdisk.
rm -rf "$DEST/../../data" 2>/dev/null || true

echo
echo "==> Installed files:"
find "$DEST" -type f | sed "s|${DEST}|  vendor|" | sort

echo
echo "==> Sizes:"
du -sh "$DEST"
echo
echo "Done."
echo
echo "NOTE: these blobs are proprietary Xiaomi/MediaTek/MicroTrust binaries."
echo "      Keep them out of public git history: they are also listed in"
echo "      .gitignore."