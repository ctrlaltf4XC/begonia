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

ifeq ($(PBRP_ENABLE_CRYPTO),true)
    PRODUCT_PROPERTY_OVERRIDES += ro.pbrp.crypto=true
else
    PRODUCT_PROPERTY_OVERRIDES += ro.pbrp.crypto=false
endif

# ---------------------------------------------------------------------------
# Optional hardware-backed decryption stack
# ---------------------------------------------------------------------------
# Keep the default image free of the vendor keymaster/TEE path. PBRP enters
# Decrypt_Data() after drawing the splash, so a blocked HAL can strand the UI
# there indefinitely.
ifeq ($(PBRP_ENABLE_CRYPTO),true)
    TARGET_RECOVERY_DEVICE_MODULES += \
        libkeymaster4 \
        libpuresoftkeymasterdevice \
        libshim_beanpod

    TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
        $(TARGET_OUT_SHARED_LIBRARIES)/libkeymaster4.so \
        $(TARGET_OUT_SHARED_LIBRARIES)/libpuresoftkeymasterdevice.so

    PRODUCT_PACKAGES += \
        libshim_beanpod
endif

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