#!/usr/bin/env bash
#
# begonia-layout-detect.sh
#
# Historically this was used to pick a single dual-layout image at runtime.
# That approach is removed now: TWRP's Prepare_Super_Volume() busy-waits on an
# unresolvable logical fstab entry with no timeout, so one fstab cannot serve
# both static and dynamic firmware. Two images are now built instead, and the
# correct one is flashed for the existing ROM.
#
# This script is kept for compatibility with scripts that still call it, but
# it only reports what the current fstab variant used at build time was.
#

exec >> /tmp/begonia-layout.log 2>&1
echo "--- begonia layout detection (legacy script, runs on post-fs-data) ---"

# Read the fstab being used by the recovery image to report which variant was
# built, not to hot-switch in-flight.
FSTAB="/system/etc/twrp.flags"
if [ -f "$FSTAB" ]; then
    # Detect the slot the recovery was built with: static images use /super
    # as a recovery image partition definition when present. The dynamic image
    # exposes logical system/system_ext/product/vendor/odm.
    HAS_SUPER=$(grep -c '/super' "$FSTAB" 2>/dev/null || true)
    echo "twrp.flags references /super: count=$HAS_SUPER"
    if [ "$HAS_SUPER" -gt 0 ]; then
        echo "built-with-variant: dynamic"
        setprop ro.begonia.layout dynamic
    else
        echo "built-with-variant: static"
        setprop ro.begonia.layout non-dynamic
    fi
else
    setprop ro.begonia.layout unknown
fi
echo "detected layout: $(getprop ro.begonia.layout)"
exit 0