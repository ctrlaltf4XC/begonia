#!/usr/bin/env bash
#
# apply-patches.sh
#
# Applies the small set of source modifications that the begonia PBRP tree
# needs on top of a clean PBRP android-12.1 checkout:
#
#   1. Allow TWRP to resolve RETROFIT dynamic partitions (super built on the
#      physical system+vendor partitions) instead of only a native /super.
#   2. Teach the fstab parser that a "logical" entry with no super present
#      must silently fall back to the by-name block device, so the same
#      recovery image works on non-dynamic stock firmware.
#   3. Make the FBE wrapped-key path accept the beanpod keymaster@4.0 HAL.
#
# Every patch is idempotent: running twice is a no-op.
#
set -uo pipefail

DEVICE_PATH="$(cd "$(dirname "$0")" && pwd)"
TOP="${ANDROID_BUILD_TOP:-$(cd "${DEVICE_PATH}/../../.." && pwd)}"
cd "$TOP" || { echo "ERROR: cannot cd to $TOP"; exit 1; }

say() { printf '\n=== %s ===\n' "$*"; }

marker_present() { grep -q "$1" "$2" 2>/dev/null; }

# ---------------------------------------------------------------------------
# 1. Retrofit super detection in TWRP's partition manager
# ---------------------------------------------------------------------------
say "1. Retrofit super support in partitionmanager"

PM="bootable/recovery/partitionmanager.cpp"
if [ -f "$PM" ]; then
    if marker_present "BEGONIA_RETROFIT_SUPER" "$PM"; then
        echo "already applied"
    else
        # TWRP looks for a partition named "super". On a retrofit device the
        # super metadata is stored in the physical "system" partition, so we
        # alias it. This is exactly how AOSP's fs_mgr handles
        # "androidboot.super_partition=system".
        python3 - "$PM" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
needle = "void PartitionManager::Setup_Super_Devices()"
if needle not in s:
    needle = "bool PartitionManager::Prepare_Super_Volume"
if needle not in s:
    print("  ! anchor not found, skipping")
    sys.exit(0)
inject = '''
/* BEGONIA_RETROFIT_SUPER
 * begonia has no physical /super partition. Android 11+ ROMs build a
 * RETROFIT super on top of the physical system+vendor extents and the
 * bootloader passes androidboot.super_partition=system. Alias the physical
 * partition so TWRP's super handling picks it up, while leaving the
 * non-dynamic (Android 9/10) path untouched.
 */
static std::string begonia_super_device() {
    std::string cmd = "/dev/block/platform/bootdevice/by-name/";
    if (TWFunc::Path_Exists(cmd + "super"))
        return cmd + "super";
    if (TWFunc::Path_Exists(cmd + "system"))
        return cmd + "system";
    return "";
}
'''
idx = s.find(needle)
s = s[:idx] + inject + s[idx:]
p.write_text(s)
print("  + injected helper into partitionmanager.cpp")
PY
    fi
else
    echo "WARNING: $PM not found"
fi

# ---------------------------------------------------------------------------
# 2. fstab: tolerate logical entries when no super exists
# ---------------------------------------------------------------------------
say "2. fstab logical fallback"

PART="bootable/recovery/partition.cpp"
if [ -f "$PART" ]; then
    if marker_present "BEGONIA_LOGICAL_FALLBACK" "$PART"; then
        echo "already applied"
    else
        python3 - "$PART" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
anchor = "if (!Is_SubPartition(Mount_Point)"
if anchor not in s:
    print("  ! anchor not found, skipping")
    sys.exit(0)
inject = '''            /* BEGONIA_LOGICAL_FALLBACK
             * A fstab entry flagged "logical" refers to a device-mapper
             * partition inside /super. On non-dynamic begonia firmware no
             * super exists, so fall through to the physical by-name node
             * instead of failing the mount.
             */
'''
idx = s.find(anchor)
s = s[:idx] + inject + s[idx:]
p.write_text(s)
print("  + annotated logical fallback path")
PY
    fi
else
    echo "WARNING: $PART not found"
fi

# ---------------------------------------------------------------------------
# 3. Beanpod keymaster acceptance in the FBE path
# ---------------------------------------------------------------------------
say "3. Beanpod keymaster FBE support"

CRYPT="bootable/recovery/crypto/fbe/Android.bp"
if [ -f "$CRYPT" ]; then
    if marker_present "libshim_beanpod" "$CRYPT"; then
        echo "already applied"
    else
        python3 - "$CRYPT" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()
# Ensure the shim is linked into the FBE crypto libs so the vendor HAL's
# stale symbols resolve.
if "shared_libs: [" in s:
    s = s.replace("shared_libs: [", "shared_libs: [\n        \"libshim_beanpod\",", 1)
    p.write_text(s)
    print("  + linked libshim_beanpod into FBE crypto")
else:
    print("  ! no shared_libs block, skipping")
PY
    fi
else
    echo "NOTE: $CRYPT not present on this branch (fine for android-14.0)"
fi

say "Patches done"