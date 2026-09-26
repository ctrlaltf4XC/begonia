#!/usr/bin/env bash
#
# Apply the begonia-specific PBRP source patches.
#
# The default safe build does not need crypto or retrofit-super patches. The
# dynamic build gets a bounded logical-partition wait so a layout mismatch can
# never leave recovery spinning forever on the splash screen.
#
set -euo pipefail

DEVICE_PATH="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${ANDROID_BUILD_TOP:-}" ]; then
    TOP="$ANDROID_BUILD_TOP"
else
    TOP=""
    for candidate in "${DEVICE_PATH}/../.." "${DEVICE_PATH}/../../../.."; do
        if [ -f "${candidate}/build/envsetup.sh" ] || [ -d "${candidate}/.repo" ]; then
            TOP="$(cd "$candidate" && pwd)"
            break
        fi
    done
fi
[ -n "$TOP" ] || { echo "ERROR: set ANDROID_BUILD_TOP to the PBRP checkout root" >&2; exit 1; }
VARIANT="${PBRP_VARIANT:-safe}"
cd "$TOP"

say() { printf '\n=== %s ===\n' "$*"; }
marker_present() { grep -q "$1" "$2" 2>/dev/null; }

PM="bootable/recovery/partitionmanager.cpp"
[ -f "$PM" ] || { echo "ERROR: missing $PM"; exit 1; }

# ---------------------------------------------------------------------------
# 1. Retrofit super detection
# ---------------------------------------------------------------------------
# begonia has no physical by-name/super node on any variant, so this is always
# required: without it Get_Super_Partition() returns /dev/block/by-name/super,
# which does not exist, and logical partitions never resolve.
if true; then
    say "1. Retrofit super support in partitionmanager"
    if marker_present "BEGONIA_RETROFIT_SUPER" "$PM"; then
        echo "already applied"
    else
        python3 - "$PM" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text()
needle = "std::string TWPartitionManager::Get_Super_Partition() {"
old_tail = 'return "/dev/block/by-name/" + super_device;'
if needle not in s or old_tail not in s:
    raise SystemExit("ERROR: PBRP retrofit-super anchors were not found")

inject = '''/* BEGONIA_RETROFIT_SUPER
 * begonia has no physical super partition. Android 11+ retrofit builds place
 * super metadata on the physical system partition and announce that choice
 * with androidboot.super_partition=system.
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
s = s.replace(
    old_tail,
    'return begonia_super_partition_path("/dev/block/by-name/" + super_device);',
    1,
)
p.write_text(s)
print("  + patched Get_Super_Partition() for retrofit super")
PY
    fi
fi

# ---------------------------------------------------------------------------
# 2. Bound the logical-partition wait
# ---------------------------------------------------------------------------
# Upstream PBRP waits forever after fs_mgr_update_logical_partition() reports
# success but the mapper node never appears. That is a real splash hang when a
# dynamic image is flashed on a static layout (or vice versa).
say "2. Bounded logical-partition wait"
if marker_present "BEGONIA_LOGICAL_WAIT_TIMEOUT" "$PM"; then
    echo "already applied"
else
    python3 - "$PM" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = '''\twhile (access(fstabEntry.blk_device.c_str(), F_OK) != 0) {
\t\tusleep(100);
\t}
'''
new = '''\t/* BEGONIA_LOGICAL_WAIT_TIMEOUT: never wait forever for a mapper node. */
\tfor (int retry = 0; retry < 100; ++retry) {
\t\tif (access(fstabEntry.blk_device.c_str(), F_OK) == 0)
\t\t\tbreak;
\t\tusleep(100000);
\t}
\tif (access(fstabEntry.blk_device.c_str(), F_OK) != 0) {
\t\tLOGERR("Timed out waiting for logical partition %s\\n", fstabEntry.blk_device.c_str());
\t\treturn false;
\t}
'''
if old not in s:
    raise SystemExit("ERROR: PBRP logical-partition wait anchor was not found")
p.write_text(s.replace(old, new, 1))
print("  + bounded logical-partition wait to 10 seconds")
PY
fi

# ---------------------------------------------------------------------------
# 3. Guard metadata FBE decryption on a mounted key directory
# ---------------------------------------------------------------------------
# Saikrishna1504's recovery fork avoids entering fscrypt when /metadata could
# not be mounted. The upstream code calls the vendor fscrypt helper anyway,
# which can block during post-splash startup on begonia.
say "3. Guard metadata FBE decryption"
if marker_present "BEGONIA_FBE_METADATA_GUARD" "$PM"; then
    echo "already applied"
else
    python3 - "$PM" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text()
old = '''\t\tTWPartition* Key_Directory_Partition = Find_Partition_By_Path(Decrypt_Data->Key_Directory);
\t\tif (Key_Directory_Partition != nullptr)
\t\t\tif (!Key_Directory_Partition->Is_Mounted())
\t\t\t\tMount_By_Path(Decrypt_Data->Key_Directory, false);
\t\tif (!Decrypt_Data->Key_Directory.empty()) {
\t\t\tSet_Crypto_Type("file");
'''
new = '''\t\t/* BEGONIA_FBE_METADATA_GUARD: do not call fscrypt without /metadata. */
\t\tif (!Decrypt_Data->Key_Directory.empty() &&
\t\t\t\tMount_By_Path(Decrypt_Data->Key_Directory, false)) {
\t\t\tSet_Crypto_Type("file");
'''
if old not in s:
    raise SystemExit("ERROR: PBRP metadata-decrypt anchor was not found")
p.write_text(s.replace(old, new, 1))
print("  + guarded metadata FBE decryption on a mounted key directory")
PY
fi

# ---------------------------------------------------------------------------
# 4. Do not inject the ABI shim into every FBE library
# ---------------------------------------------------------------------------
# libshim_beanpod is linked only by the explicit crypto build in device.mk.
# Injecting it into PBRP's FBE library globally can interpose incomplete
# keymaster symbols and is not needed by the safe build.
say "4. Beanpod FBE shim"
echo "handled by the conditional module list in device.mk; no global FBE injection"

say "Patches done"
