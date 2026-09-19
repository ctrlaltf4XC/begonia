#!/usr/bin/env bash
#
# apply-patches.sh
#
# Applies the small set of source modifications that the begonia PBRP tree
# needs on top of a clean PBRP android-12.1 checkout:
#
#   1. Let TWRP find the RETROFIT super on begonia, where the super metadata
#      lives in the physical "system" partition instead of a "super" one.
#   2. Make the FBE wrapped-key path accept the beanpod keymaster@4.0 HAL.
#
# Partition layout is NOT handled by patching: TWRP's Prepare_Super_Volume()
# busy-waits on an unresolvable logical device with no timeout, so a "logical"
# fstab entry on non-dynamic firmware hangs recovery. Two fstab variants are
# shipped instead (variants/) and one is selected via select-fstab.sh.
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
        # TWRP resolves the super via:
        #     std::string TWPartitionManager::Get_Super_Partition() {
        #         int slot_number = Get_Active_Slot_Display() == "A" ? 0 : 1;
        #         std::string super_device = fs_mgr_get_super_partition_name(slot_number);
        #         return "/dev/block/by-name/" + super_device;
        #     }
        # and everything else keys off access() on that path. On begonia there
        # is no "super" partition: the super is a retrofit built onto the
        # system+vendor extents and the bootloader announces it via
        # androidboot.super_partition=system. Rewrite the returned path to the
        # by-name node the kernel actually exposes, so Get_Super_Status(),
        # Setup_Super_Devices() and CreateLogicalPartitions() all work.
        python3 - "$PM" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()

needle = "std::string TWPartitionManager::Get_Super_Partition() {"
if needle not in s:
    print("  ! Get_Super_Partition() anchor not found, skipping")
    sys.exit(0)

old_tail = 'return "/dev/block/by-name/" + super_device;'
if old_tail not in s:
    print("  ! return statement anchor not found, skipping")
    sys.exit(0)

inject = '''/* BEGONIA_RETROFIT_SUPER
 * begonia has no physical super partition. Android 11..16 ROMs build a
 * RETROFIT super on top of the physical system+vendor extents and the
 * bootloader passes androidboot.super_partition=system. The kernel exposes it
 * as a by-name node named after that argument, so translate the generic
 * "super" name to it. On a device that really has a super partition the
 * plain path is used, so nothing changes for non-dynamic firmware.
 */
static std::string begonia_super_partition_path(const std::string& candidate) {
    const char* kBy = "/dev/block/platform/bootdevice/by-name/";
    if (TWFunc::Path_Exists(candidate))
        return candidate;
    if (TWFunc::Path_Exists(std::string(kBy) + "system"))
        return std::string(kBy) + "system";
    return candidate;
}
'''

idx = s.find(needle)
s = s[:idx] + inject + s[idx:]

# Wrap the return value through the helper.
s = s.replace(old_tail, "return begonia_super_partition_path(\"/dev/block/by-name/\" + super_device);", 1)
p.write_text(s)
print("  + patched Get_Super_Partition() for retrofit super")
PY
    fi
else
    echo "WARNING: $PM not found"
fi

# ---------------------------------------------------------------------------
# 2. (removed)
#
# An earlier revision patched partition.cpp to make a "logical" fstab entry
# fall back to the physical by-name device. That was wrong: TWRP's
# TWPartitionManager::Prepare_Super_Volume() drops the partition and then
# busy-waits on access() with no timeout, so patching it that way hides a
# hang instead of fixing it.
#
# The correct fix, implemented in this tree, is to ship two fstab variants and
# select one at build time (variants/recovery.fstab.static /.dynamic via
# select-fstab.sh). Nothing to patch here.
# ---------------------------------------------------------------------------
say "2. fstab variants (no source patch needed)"
echo "handled by variants/recovery.fstab.{static,dynamic} + select-fstab.sh"

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