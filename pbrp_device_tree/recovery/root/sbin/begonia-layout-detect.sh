#!/system/bin/sh
#
# begonia-layout-detect.sh
#
# Runs from the recovery ramdisk at post-fs-data time. Detects which partition
# layout the currently installed ROM uses and publishes it as a property so
# scripts and the PBRP UI can behave accordingly.
#
#   ro.begonia.layout = "dynamic"      -> Android 11..16, /super over
#                                         physical system+vendor extents
#   ro.begonia.layout = "non-dynamic"  -> stock Android 9/10, plain
#                                         system/vendor partitions
#
# This is what lets ONE recovery image serve both layouts.

LOG=/tmp/begonia-layout.log
exec >> "$LOG" 2>&1

echo "--- begonia layout detection ---"
echo "cmdline: $(cat /proc/cmdline)"

SUPER_META="/dev/block/platform/bootdevice/by-name/system"
LAYOUT="non-dynamic"

# 1. Kernel tells us directly on retrofit devices
if grep -q 'androidboot.super_partition=' /proc/cmdline; then
    echo "androidboot.super_partition present in cmdline"
    LAYOUT="dynamic"
fi

# 2. An explicit native super partition (not the case on begonia, but cheap)
if [ -e /dev/block/platform/bootdevice/by-name/super ]; then
    echo "native super partition found"
    LAYOUT="dynamic"
fi

# 3. Probe the super metadata magic at the start of the physical system
#    partition. The LP metadata header has the magic "0x414C5030" stored
#    little-endian, preceded by "LP" style geometry; checking for the
#    super-block device-mapper node is more reliable in recovery, so use
#    the mapper directory as the primary signal.
if [ -d /dev/block/mapper ] && [ -n "$(ls -A /dev/block/mapper 2>/dev/null)" ]; then
    echo "device-mapper super nodes present:"
    ls -1 /dev/block/mapper
    LAYOUT="dynamic"
fi

# 4. Last resort: look for the LP metadata magic on the backing device.
if [ "$LAYOUT" = "non-dynamic" ] && [ -e "$SUPER_META" ]; then
    MAGIC=$(dd if="$SUPER_META" bs=1 skip=4096 count=4 2>/dev/null | od -An -tx4 2>/dev/null | tr -d ' \n')
    echo "probed magic at offset 4096: $MAGIC"
    case "$MAGIC" in
        414c5030*|*414c5030) LAYOUT="dynamic" ;;
    esac
fi

echo "detected layout: $LAYOUT"
setprop ro.begonia.layout "$LAYOUT"

if [ "$LAYOUT" = "dynamic" ]; then
    # Give the logical partitions a moment to appear, then map them so that
    # backup/restore of system, vendor, product, system_ext and odm works.
    for p in system vendor product system_ext odm; do
        if [ ! -e "/dev/block/mapper/$p" ]; then
            dmctl create "$p" 2>/dev/null || true
        fi
    done
    ls -1 /dev/block/mapper 2>/dev/null
else
    echo "non-dynamic layout: system/vendor are physical partitions"
fi

exit 0