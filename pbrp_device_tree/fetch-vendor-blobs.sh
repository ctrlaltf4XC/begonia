#!/usr/bin/env bash
#
# fetch-vendor-blobs.sh
#
# Downloads the MicroTrust "beanpod" TEE decryption stack from the device's
# Android 10 MIUI firmware / LineageOS vendor tree and installs it into the
# recovery ramdisk. Run this from the device tree root before building.
#
# These are the exact blobs (keymaster@4.0-service.beanpod, gatekeeper,
# teei_daemon, TAs) that make hardware-wrapped-key FBE decryption work on
# Android 10 through Android 16 ROMs.
#
# Usage:
#   cd device/xiaomi/begonia
#   ./fetch-vendor-blobs.sh            # extract from an existing vendor tree
#
set -euo pipefail

DEVICE_PATH="$(cd "$(dirname "$0")" && pwd)"
DEST="${DEVICE_PATH}/recovery/root/vendor"

# Preferred source: an existing extracted vendor tree (proprietary blobs).
POSSIBLE_VENDORS=(
    "${ANDROID_BUILD_TOP:-}/vendor/xiaomi/begonia/proprietary"
    "${ANDROID_BUILD_TOP:-}/vendor/xiaomi/mt6785-common/proprietary"
    "${ANDROID_BUILD_TOP:-}/vendor/redmi/begonia/proprietary"
)

SRC=""
for v in "${POSSIBLE_VENDORS[@]}"; do
    if [ -n "${ANDROID_BUILD_TOP:-}" ] && [ -d "$v" ]; then
        SRC="$v"
        break
    fi
done

if [ -z "$SRC" ]; then
    echo "ERROR: no extracted vendor tree found."
    echo "       Set ANDROID_BUILD_TOP or extract the vendor image first:"
    echo "         ./extract-files.sh /path/to/dump"
    exit 1
fi

echo "Using vendor tree: $SRC"

mkdir -p "$DEST/bin/hw" "$DEST/lib64/hw" "$DEST/lib64" "$DEST/thh/ta" \
         "$DEST/etc/vintf" "$DEST/etc/init"

copy() {
    local rel="$1"
    if [ -f "${SRC}/${rel}" ]; then
        mkdir -p "$(dirname "${DEST}/${rel}")"
        cp -f "${SRC}/${rel}" "${DEST}/${rel}"
        echo "  + ${rel}"
    else
        echo "  ! missing: ${rel}"
    fi
}

echo "== keymaster / gatekeeper HAL binaries =="
copy vendor/bin/hw/android.hardware.keymaster@4.0-service.beanpod
copy vendor/bin/hw/android.hardware.gatekeeper@1.0-service
copy vendor/bin/teei_daemon

echo "== keymaster / gatekeeper libraries =="
copy vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl.so
copy vendor/lib64/hw/gatekeeper.beanpod.so
copy vendor/lib64/hw/gatekeeper.default.so
copy vendor/lib64/hw/kmsetkey.beanpod.so
copy vendor/lib64/hw/libSoftGatekeeper.so
copy vendor/lib64/libkeymaster4.so
copy vendor/lib64/libkeymaster4support.so
copy vendor/lib64/libkeymaster_messages.so
copy vendor/lib64/libkeymaster_portable.so
copy vendor/lib64/libpuresoftkeymasterdevice.so
copy vendor/lib64/libTEECommon.so
copy vendor/lib64/libimsg_log.so
copy vendor/lib64/libmtee.so

echo "== TEE init scripts =="
copy vendor/etc/init/android.hardware.keymaster@4.0-service.beanpod.rc
copy vendor/etc/init/android.hardware.gatekeeper@1.0-service.rc

echo "== Trusted Applications (TAs) =="
for ta in "${SRC}"/vendor/thh/ta/*.ta; do
    [ -e "$ta" ] || continue
    cp -f "$ta" "$DEST/thh/ta/"
done
echo "  + $(ls -1 "$DEST/thh/ta" | wc -l) TA files"

echo
echo "Done. Blobs installed into recovery/root/vendor"
echo "Remember: these files are proprietary and must NOT be redistributed."