#
# Copyright (C) 2022-2026 The PitchBlack Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Shipping API level (Android 10) - keeps the beanpod KM4/GK1 HALs valid
PRODUCT_SHIPPING_API_LEVEL := 29

# Prevent vendor anti-rollback on any ROM generation
PRODUCT_PROPERTY_OVERRIDES += \
    ro.vendor.build.security_patch=2099-12-31 \
    ro.bootimage.build.date.utc=0 \
    ro.build.date.utc=0

# ---------------------------------------------------------------------------
# Decryption stack (FDE + FBE v1/v2 + hardware wrapped keys)
#
# The MicroTrust "beanpod" keymaster 4.0 and gatekeeper 1.0 HALs need to be
# relinked into the recovery ramdisk together with their shim, because the
# vendor implementations were built against an older libkeymaster_messages.
# ---------------------------------------------------------------------------
TARGET_RECOVERY_DEVICE_MODULES += \
    libkeymaster4 \
    libpuresoftkeymasterdevice \
    libkeymaster4support \
    libkeymaster_portable \
    libkeymaster_messages \
    libshim_beanpod

TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libkeymaster4.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libpuresoftkeymasterdevice.so

PRODUCT_PACKAGES += \
    libshim_beanpod

# ---------------------------------------------------------------------------
# Extra recovery utilities
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    toybox \
    busybox \
    e2fsprogs \
    fsck.f2fs \
    mkfs.f2fs \
    lptools \
    lpdump \
    sgdisk \
    parted \
    bash \
    nano \
    vim

# Ensure the dynamic-partition tooling is on the recovery image
PRODUCT_PACKAGES += \
    liblp \
    libdm

# External filesystem support
PRODUCT_PACKAGES += \
    fuse-exfat \
    exfat-fuse \
    ntfs-3g