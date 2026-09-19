#
# libshim_beanpod - ABI shim for the MicroTrust "beanpod" keymaster HAL
#
# The vendor keymaster@4.0-service.beanpod binary and libkeymaster4.so were
# built against an older libkeymaster_messages ABI than the one shipped with
# the current recovery. Symbol mangling changed for:
#
#   keymaster::GenerateKeyResponse::~GenerateKeyResponse()
#   keymaster::AttestKeyResponse::~AttestKeyResponse()
#   keymaster::ImportKeyRequest::SetKeyMaterial(const void*, size_t)
#
# Without this shim the keymaster HAL aborts, keymaster never comes up, and
# FBE (wrapped key) decryption fails. Linking this shim restores those
# symbols so the TEE keymaster can be used to unwrap the /data keys.
#

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := libshim_beanpod
LOCAL_MODULE_TAGS := optional
LOCAL_MULTILIB := first

ifeq ($(TARGET_IS_64_BIT),true)
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/lib64
LOCAL_PROPRIETARY_MODULE := true
else
LOCAL_MODULE_PATH := $(TARGET_RECOVERY_ROOT_OUT)/vendor/lib
endif

LOCAL_SRC_FILES := \
    libshim_beanpod.cpp

LOCAL_SHARED_LIBRARIES := \
    libkeymaster_messages \
    liblog

LOCAL_HEADER_LIBRARIES := \
    libhardware_headers

LOCAL_C_INCLUDES := \
    system/keymaster/include

LOCAL_CFLAGS := -Wall -Wno-unused-parameter

include $(BUILD_SHARED_LIBRARY)