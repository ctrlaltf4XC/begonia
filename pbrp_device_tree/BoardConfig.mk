#
# Copyright (C) 2022-2026 The PitchBlack Recovery Project
# Copyright (C) 2022 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#
# Device configuration for Redmi Note 8 Pro (begonia / begoniain)
# SoC: MediaTek Helio G90T (MT6785)
#
# Supports BOTH partition layouts:
#   1. Non-dynamic (stock Android 9/10 firmware) -> physical system/vendor
#   2. Retrofit dynamic (Android 11+ / Android 16 ROMs) -> /super over system+vendor
#
# Decryption: FDE (AES-256-XTS) and FBE v1/v2 including hardware wrapped keys
# (MicroTrust "beanpod" TEE: teei_daemon + keymaster@4.0 + gatekeeper@1.0).
#

DEVICE_PATH := device/xiaomi/begonia

# Build-time recovery modes. The default is a no-crypto startup image; crypto
# is explicit because the MicroTrust HAL can block before the UI is loaded.
PBRP_ENABLE_CRYPTO ?= false
PBRP_VARIANT ?= safe

# ----------------------------------------------------------------------------
# Minimal manifest build relaxation
# ----------------------------------------------------------------------------
ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# ----------------------------------------------------------------------------
# Architecture
# ----------------------------------------------------------------------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_USES_64_BIT_BINDER := true
TARGET_IS_64_BIT := true

# ----------------------------------------------------------------------------
# Bootloader / Platform
# ----------------------------------------------------------------------------
TARGET_BOOTLOADER_BOARD_NAME := begonia
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := mt6785
TARGET_BOARD_PLATFORM_GPU := mali-g76mc4
BOARD_HAS_MTK_HARDWARE := true
# ----------------------------------------------------------------------------
# Kernel (prebuilt, MTK boot image v2)
# ----------------------------------------------------------------------------
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
BOARD_KERNEL_CMDLINE += androidboot.usbconfigfs=true
# begonia is a retrofit-dynamic device: super metadata lives in the physical
# by-name/system extent and the five mountable partitions are dm-0..dm-4.
# The bootloader passes this on the working TWRP image, and liblp will not
# resolve the logical partitions without it -- recovery then falls back to
# mounting by-name/system, which is the super container and not a filesystem.
# Required for every variant on this device.
BOARD_KERNEL_CMDLINE += androidboot.super_partition=system
# A fatal init error should leave recovery rather than loop on its splash.
BOARD_KERNEL_CMDLINE += androidboot.init_fatal_reboot_target=bootloader

BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_KERNEL_SECOND_OFFSET := 0x00e88000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_TAGS_OFFSET := 0x0bc08000
BOARD_RAMDISK_OFFSET := 0x07c08000
BOARD_DTB_OFFSET := 0x0bc08000
BOARD_KERNEL_IMAGE_NAME := Image.gz
BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_KERNEL_SEPARATED_DTBO := true
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_INCLUDE_RECOVERY_DTBO := true

TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image.gz
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtb
BOARD_PREBUILT_DTBIMAGE := $(BOARD_PREBUILT_DTBIMAGE_DIR)/mtk.dtb
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --second_offset $(BOARD_KERNEL_SECOND_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --base $(BOARD_KERNEL_BASE)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)

LOCAL_KERNEL := $(DEVICE_PATH)/prebuilt/Image.gz

# ----------------------------------------------------------------------------
# Assert
# ----------------------------------------------------------------------------
TARGET_OTA_ASSERT_DEVICE := begonia,begoniain
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt

# ----------------------------------------------------------------------------
# AVB / anti-rollback
# ----------------------------------------------------------------------------
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# Beat vendor anti-rollback so older/newer ROMs both flash fine
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)

# ----------------------------------------------------------------------------
# Partitions - physical geometry (identical on both layouts)
# ----------------------------------------------------------------------------
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 33554432
BOARD_CACHEIMAGE_PARTITION_SIZE := 452984832
BOARD_USERDATAIMAGE_PARTITION_SIZE := 120116445184

# Physical extents that make up the retrofit /super
BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE := 3758096384
BOARD_SUPER_PARTITION_VENDOR_DEVICE_SIZE := 1610612736

# ----------------------------------------------------------------------------
# Partitions - retrofit /super (dynamic partitions)
#
# begonia has no native "super" partition, so Android 11+ ROMs use RETROFIT
# dynamic partitions: a super built on top of the "system" and "vendor"
# physical partitions. These values match the layout used by the maintained
# begonia ROM trees, so recovery can map, resize and flash them correctly.
# ----------------------------------------------------------------------------
# Every dynamic partition is ext4 in recovery's view.
# Written out explicitly: dumpvars parses this file in a stricter context than a
# bare `include`, and the $(eval) these used to be generated blew up there with
# "missing separator" on the line after the loop. Don't fold this back into a
# $(foreach)/$(eval) loop -- plain assignments parse everywhere.
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4

# AOSP names these with the partition uppercased and the value lowercased --
# board_config.mk rejects e.g. TARGET_COPY_OUT_vendor when BOARD_USES_VENDOR_IMAGE
# is set, so the name case is load-bearing here.
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM := system
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_VENDOR := vendor

BOARD_PRODUCTIMAGE_EXTFS_INODE_COUNT := -1
BOARD_SYSTEMIMAGE_EXTFS_INODE_COUNT := -1
BOARD_SYSTEM_EXTIMAGE_EXTFS_INODE_COUNT := -1
BOARD_ODMIMAGE_EXTFS_INODE_COUNT := 4096
BOARD_VENDORIMAGE_EXTFS_INODE_COUNT := 4096

# 80 MB reserved on the non-treble dynamic partitions
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE := 83886080
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 83886080
BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE := 83886080

# 40 MB reserved on the treble dynamic partitions
BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE := 41943040
BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE := 41943040

BOARD_SUPER_PARTITION_BLOCK_DEVICES := vendor system
BOARD_SUPER_PARTITION_METADATA_DEVICE := system
BOARD_SUPER_PARTITION_GROUPS := xiaomi_dynamic_partitions
BOARD_SUPER_PARTITION_VENDOR_DEVICE_SIZE := 1610612736
BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE := 3758096384
BOARD_SUPER_PARTITION_SIZE := $(shell expr $(BOARD_SUPER_PARTITION_VENDOR_DEVICE_SIZE) + $(BOARD_SUPER_PARTITION_SYSTEM_DEVICE_SIZE))
BOARD_XIAOMI_DYNAMIC_PARTITIONS_PARTITION_LIST := odm product system system_ext vendor
BOARD_XIAOMI_DYNAMIC_PARTITIONS_SIZE := $(shell expr $(BOARD_SUPER_PARTITION_SIZE) - 4194304)

# ----------------------------------------------------------------------------
# Filesystems (recovery must READ and WRITE all of these)
#   ext4       - stock / Android 9-11
#   f2fs       - Android 12+
#   erofs      - Android 13+ system/vendor/product
#   exfat/ntfs - external media
# ----------------------------------------------------------------------------
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true

BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

# EROFS read support (Android 13/14/15/16 system images)
# Recovery must be able to *read* erofs even though the dynamic partitions
# above are declared ext4, because A16 ROMs ship erofs system/vendor images.
BOARD_EROFS_COMPRESSOR := lz4hc
BOARD_EROFS_USE_ZTAILPACKING := true
BOARD_EROFS_PCLUSTER_SIZE := 262144

# ----------------------------------------------------------------------------
# Properties / encryption
# ----------------------------------------------------------------------------
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
ifeq ($(PBRP_ENABLE_CRYPTO),true)
    TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
    TARGET_SYSTEM_PROP += $(DEVICE_PATH)/crypto.prop
    TW_INCLUDE_CRYPTO := true
    TW_INCLUDE_CRYPTO_FBE := true
    TW_INCLUDE_FBE_METADATA_DECRYPT := true
    TW_CRYPTO_SYSTEM_USER := true
    ifeq ($(BEANPOD_FSCRYPT_V2),true)
        TW_USE_FSCRYPT_POLICY := 2
    else
        TW_USE_FSCRYPT_POLICY := 1
    endif
else
    # Intentionally empty. PBRP's Android.mk uses ifneq(TW_INCLUDE_CRYPTO,), so
    # assigning "false" would still pull keystore/vold into the build; simply not
    # assigning the TW_*CRYPTO* vars above leaves them undefined, which is what
    # keeps the crypto path out. Don't restore `undefine` here to spell that out
    # -- make rejects it at this line with "missing separator" under dumpvars.
endif

# ----------------------------------------------------------------------------
# Dynamic partitions / logical volume tooling
# ----------------------------------------------------------------------------
TW_INCLUDE_LPTOOLS := true
TW_INCLUDE_LPDUMP := true
TW_INCLUDE_LPFLASH := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_NTFS_3G := true
TW_INCLUDE_FUSE_EXFAT := true
TW_INCLUDE_FUSE_NTFS := true

# ----------------------------------------------------------------------------
# Recovery configuration
# ----------------------------------------------------------------------------
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_RECOVERY_DEVICE_DIRS += $(DEVICE_PATH)
# NOTE: TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT was removed on purpose.
# It forces a display blank/unblank during recovery init, which on MTK lands in
# the driver's wait_event path that the failing dmesg showed:
#   [DISP][_ioctl_wait_self_refresh_trigger] ERROR:[REPAINT] wait_event
# unexpectedly, ret:-512
# The known-working begonia tree does not set it.
TARGET_RECOVERY_LED_PATH := /sys/class/leds/lcd-backlight/brightness
TARGET_RECOVERY_ALLOW_OFF_CHARGING := true

# ----------------------------------------------------------------------------
# TWRP / PBRP build flags
# ----------------------------------------------------------------------------
TW_THEME := portrait_hdpi
TW_DEVICE_VERSION := begonia-dynd
# The PBRP GUI performs an MTK framebuffer blank/unblank when this is true;
# that wait can keep a device on the splash image. Keep it disabled.
TW_SCREEN_BLANK_ON_BOOT := false
TW_Y_OFFSET := 80
TW_H_OFFSET := -80
TW_FRAMERATE := 60
TW_EXTRA_LANGUAGES := true
TW_USE_TOOLBOX := true
TW_EXCLUDE_APEX := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXCLUDE_TWRPAPP := true
TW_SKIP_COMPATIBILITY_CHECK := true
TW_DEFAULT_BRIGHTNESS := 1024
TW_MAX_BRIGHTNESS := 2047
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_CUSTOM_CPU_TEMP_PATH := /sys/devices/virtual/thermal/thermal_zone4/temp
TW_INPUT_BLACKLIST := "hbtp_vm"
ifeq ($(PBRP_ENABLE_CRYPTO),true)
    TW_PREPARE_DATA_MEDIA_EARLY := true
else
    TW_PREPARE_DATA_MEDIA_EARLY := false
endif
TW_HAS_MTP := true
TW_HAS_EDL_MODE := true
ifeq ($(PBRP_ENABLE_CRYPTO),true)
    RECOVERY_SDCARD_ON_DATA := true
else
    RECOVERY_SDCARD_ON_DATA := false
endif
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false
TARGET_USE_CUSTOM_LUN_FILE_PATH := /config/usb_gadget/g1/functions/mass_storage.0/lun.%d/file

# Internal / external storage mapping
TW_INTERNAL_STORAGE_PATH := "/data/media"
TW_INTERNAL_STORAGE_MOUNT_POINT := "data"
TW_EXTERNAL_STORAGE_PATH := "/external_sd"
TW_EXTERNAL_STORAGE_MOUNT_POINT := "external_sd"

# Debug
TWRP_INCLUDE_LOGCAT := true
TARGET_USES_LOGD := true

# ----------------------------------------------------------------------------
# PBRP specific flags
# ----------------------------------------------------------------------------
PB_DISABLE_DEFAULT_DM_VERITY := true
PB_DISABLE_DEFAULT_TREBLE_COMP := true
PB_TORCH_PATH := "/sys/class/leds/flash-light"

# ----------------------------------------------------------------------------
# Soong
# ----------------------------------------------------------------------------
PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)
BOARD_USES_METADATA_PARTITION := true
