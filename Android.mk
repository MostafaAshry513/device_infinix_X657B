LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),X657B)

include $(call all-makefiles-under,$(LOCAL_PATH))

# fstab.mt6761 — installed to /vendor/etc/fstab.mt6761
include $(CLEAR_VARS)
LOCAL_MODULE       := fstab.mt6761
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH  := $(TARGET_OUT_VENDOR_ETC)
LOCAL_SRC_FILES    := rootdir/etc/fstab.mt6761
include $(BUILD_PREBUILT)

endif
