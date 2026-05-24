LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),X657B)

# Pull in any sub-Android.mk files; the fstab is installed via PRODUCT_COPY_FILES in device.mk
include $(call all-makefiles-under,$(LOCAL_PATH))

endif
