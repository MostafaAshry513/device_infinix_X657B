# Device packages and properties for Infinix X657B (MT6761, 32-bit, Android Go)

# Install GSI signing keys into ramdisk — REQUIRED. Stock fstab has
# avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey
# so init's first_stage_mount needs these keys present to accept our system.
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_keys.mk)

# Pull stock vendor.img/product.img as prebuilts via the vendor tree
$(call inherit-product-if-exists, vendor/infinix/X657B/X657B-vendor.mk)

# Android Go defaults (lowram tuning, app exclusions, Go-specific configs).
$(call inherit-product, build/make/target/product/go_defaults_512.mk)

# Runtime / ART config — without this, dexpreopt_gen runs with empty -global
# and fails with "global configuration file is required" for every Java app.
# go_defaults doesn't inherit this; LineageOS's common_mini_go_phone doesn't either.
$(call inherit-product, build/make/target/product/runtime_libart.mk)

# Override go_defaults' profile-based boot image (the boot.art generation step
# isn't reliably wired up for our standalone tree, causing dex2oat to fail when
# preopting frameworks/base/ext against a missing boot.art).
PRODUCT_USE_PROFILE_FOR_BOOT_IMAGE := false

# Dalvik heap config (closer match to our 3 GB / 320 DPI than the 2048 variant)
$(call inherit-product, frameworks/native/build/phone-xhdpi-2048-dalvik-heap.mk)

# Standard 32-bit Treble overlay paths
DEVICE_PACKAGE_OVERLAYS += device/infinix/X657B/overlay

# Stock kernel + DTB are baked into our boot.img prebuilt; these only exist for
# Soong's reference (BoardConfig points at them too).
TARGET_PREBUILT_KERNEL := device/infinix/X657B/prebuilts/kernel
TARGET_PREBUILT_DTB    := device/infinix/X657B/prebuilts/dtb

# Filesystem
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# fstab.mt6761 → /vendor/etc/fstab.mt6761 (single install path)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6761:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6761

# Low-RAM tuning (matches stock Go config)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.low_ram=true \
    ro.lmk.use_psi=true

# Dynamic partitions + shipping API level (required for correct system layout
# and to keep /system mounted at /system instead of SAR — otherwise mkuserimg
# fails: "failed to find [/system] in canned fs_config")
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_SHIPPING_API_LEVEL := 29
