#!/usr/bin/env bash
#
# Select the recovery fstab variant.
#
# safe    - no /data entry; default startup/diagnostic image
# static  - by-name system/vendor; use with PBRP_ENABLE_CRYPTO=true
# dynamic - logical retrofit-super entries; use with PBRP_ENABLE_CRYPTO=true
#
set -euo pipefail

VARIANT="${1:-${PBRP_VARIANT:-safe}}"
HERE="$(cd "$(dirname "$0")" && pwd)"
FSTAB="${HERE}/recovery/root/system/etc/recovery.fstab"

case "$VARIANT" in
    safe|static|dynamic) ;;
    *) echo "usage: $0 <safe|static|dynamic>" >&2; exit 2 ;;
esac

SRC="${HERE}/variants/recovery.fstab.${VARIANT}"
[ -f "$SRC" ] || { echo "ERROR: missing $SRC" >&2; exit 1; }

cp -f "$SRC" "$FSTAB"
echo "fstab set to '${VARIANT}' (${SRC} -> ${FSTAB})"
echo
head -12 "$FSTAB"
