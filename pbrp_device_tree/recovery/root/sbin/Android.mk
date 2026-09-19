#
# Installs the recovery-only helper scripts into the ramdisk.
#

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := begonia-layout-detect.sh
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/sbin
LOCAL_SRC_FILES := begonia-layout-detect.sh
include $(BUILD_PREBUILT)