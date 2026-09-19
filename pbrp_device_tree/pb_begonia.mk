#
# Copyright (C) 2022-2026 The PitchBlack Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Inherit from the begonia device tree
$(call inherit-product, device/xiaomi/begonia/device.mk)

# Inherit common PBRP configuration
$(call inherit-product, vendor/pb/config/common.mk)

# Device identifiers. Must come after all inclusions.
BOARD_VENDOR := xiaomi
PRODUCT_DEVICE := begonia
PRODUCT_NAME := pb_begonia
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := Redmi Note 8 Pro
PRODUCT_MANUFACTURER := Xiaomi
TARGET_VENDOR := xiaomi

PRODUCT_RELEASE_NAME := begonia