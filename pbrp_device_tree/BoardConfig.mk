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
# Retrofit super: the /super metadata lives in the physical "system" partition.
# Harmless on non-dynamic layouts (kernel only reads it when super exists).
BOARD_KERNEL_CMDLINE += androidboot.super_partition=system
BOARD_KERNEL_CMDLINE += androidboot.init_fatal_reboot_target=recovery

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
SSI_PARTITIONS := product system system_ext
TREBLE_PARTITIONS := odm vendor
ALL_PARTITIONS := $(SSI_PARTITIONS) $(TREBLE_PARTITIONS)

# Every dynamic partition is ext4 in recovery's view
$(foreach p, $(call to-upper, $(ALL_PARTITIONS)), \
    $(eval BOARD_$(p)IMAGE_FILE_SYSTEM_TYPE := ext4) \
    $(eval TARGET_COPY_OUT_$(p) := $(call to-lower, $(p))))

$(foreach p, $(call to-upper, $(SSI_PARTITIONS)), \
    $(eval BOARD_$(p)IMAGE_EXTFS_INODE_COUNT := -1))
$(foreach p, $(call to-upper, $(TREBLE_PARTITIONS)), \
    $(eval BOARD_$(p)IMAGE_EXTFS_INODE_COUNT := 4096))

$(foreach p, $(call to-upper, $(SSI_PARTITIONS)), \
    $(eval BOARD_$(p)IMAGE_PARTITION_RESERVED_SIZE := 83886080)) # 80 MB
$(foreach p, $(call to-upper, $(TREBLE_PARTITIONS)), \
    $(eval BOARD_$(p)IMAGE_PARTITION_RESERVED_SIZE := 41943040)) # 40 MB

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
# Properties
# ----------------------------------------------------------------------------
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
# Metadata partition is required for FBE v2 key directory + legacy FDE
# ----------------------------------------------------------------------------
# Encryption / Decryption
#
#  * FDE  (AES-256-XTS, Android 9)                 -> TW_INCLUDE_CRYPTO
#  * FBE v1 (Android 10/11 "fscrypt")              -> TW_INCLUDE_CRYPTO_FBE
#  * FBE v2 (Android 12+ "fscrypt v2", /metadata)  -> TW_USE_FSCRYPT_POLICY := 2
#  * FBE hardware wrapped keys (Android 13-16)     -> fbe.metadata.wrappedkey
#    unwrapped through the MicroTrust beanpod TEE
#    (teei_daemon + keymaster@4.0-service.beanpod + gatekeeper@1.0-service).
#
#  Android 16 ROMs use FBE v2 with a wrapped key stored in
#  /metadata/vold/metadata_encryption and dm-default-key as the volume
#  crypto method, hence TW_INCLUDE_FBE_METADATA_DECRYPT.
# ----------------------------------------------------------------------------
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
TW_CRYPTO_SYSTEM_USER := true

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
TARGET_RECOVERY_UI_BLANK_UNBLANK_ON_INIT := true
TARGET_RECOVERY_LED_PATH := /sys/class/leds/lcd-backlight/brightness
TARGET_RECOVERY_ALLOW_OFF_CHARGING := true

# Relink the beanpod keymaster/gatekeeper stack so /data can be decrypted
TARGET_RECOVERY_DEVICE_MODULES += \
    libkeymaster4 \
    libpuresoftkeymasterdevice \
    libshim_beanpod

TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libkeymaster4.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libpuresoftkeymasterdevice.so

# ----------------------------------------------------------------------------
# TWRP / PBRP build flags
# ----------------------------------------------------------------------------
TW_THEME := portrait_hdpi
TW_DEVICE_VERSION := begonia-dynd
TW_SCREEN_BLANK_ON_BOOT := true
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
TW_PREPARE_DATA_MEDIA_EARLY := true
TW_HAS_MTP := true
TW_HAS_EDL_MODE := true
RECOVERY_SDCARD_ON_DATA := true
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
# ----------------------------------------------------------------------------
# DISPLAY DRIVER FIX - Frame Buffer Repaint Resolution
# ----------------------------------------------------------------------------
MTK_DISPLAY_SUPPORT := true
TARGET_BOARD_PLATFORM_GPU := mali-g76mc4
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TW_Y_OFFSET := 80
TW_H_OFFSET := -80
TW_DEFAULT_BRIGHTNESS := 1024
TW_MAX_BRIGHTNESS := 2047

# Display driver re-linking
TARGET_RECOVERY_DEVICE_MODULES += libdisp_drv
TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libdisp_drv.so
