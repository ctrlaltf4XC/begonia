#!/usr/bin/env bash
#
# select-fstab.sh <static|dynamic>
#
# Switches the device tree between the two recovery.fstab variants.
#
# WHY TWO VARIANTS
# ----------------
# TWRP's TWPartitionManager::Prepare_Super_Volume() resolves a fstab entry
# flagged "logical" like this:
#
#     if (partition->Is_Super && !Prepare_Super_Volume(partition))
#         goto clear;                       // partition dropped
#     ...
#     while (access(fstabEntry.blk_device.c_str(), F_OK) != 0) {
#         usleep(100);                      // NO TIMEOUT
#     }
#
# On begonia there is no physical "super" partition (the super is a retrofit
# built on the system+vendor extents), so a logical entry can never resolve on
# stock Android 9/10 firmware and recovery would busy-wait forever.
#
# Consequently a single fstab cannot serve both layouts. We build one image per
# layout instead, and this script picks the fstab before the build.
#
#   static  -> by-name system/vendor. Stock Android 9/10, and also the safe
#              default for Android 11..16 (by-name system/vendor are the super
#              backing extents; lptools handles the super itself).
#   dynamic -> logical system/system_ext/product/vendor/odm inside /super.
#              Required for installing/flashing Android 11..16 ROMs.
#
set -euo pipefail

VARIANT="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FSTAB="${HERE}/recovery/root/system/etc/recovery.fstab"

case "$VARIANT" in
    static|dynamic) ;;
    *) echo "usage: $0 <static|dynamic>"; exit 2 ;;
esac

SRC="${HERE}/variants/recovery.fstab.${VARIANT}"
[ -f "$SRC" ] || { echo "ERROR: missing $SRC"; exit 1; }

cp -f "$SRC" "$FSTAB"
echo "fstab set to '${VARIANT}' (${SRC} -> ${FSTAB})"
echo
head -12 "$FSTAB"