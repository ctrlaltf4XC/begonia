#
# Copyright (C) 2022-2026 The PitchBlack Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),begonia)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif