# Device packages and properties for Infinix X657B (MT6761, 32-bit, Android Go)

# Reuse stock vendor partition unchanged. Vendor blobs come via vendor/infinix/X657B/X657B-vendor.mk
$(call inherit-product-if-exists, vendor/infinix/X657B/X657B-vendor.mk)

# Standard 32-bit Treble overlay paths
DEVICE_PACKAGE_OVERLAYS += device/infinix/X657B/overlay

# Stock vendor partition is unchanged — no per-blob copy needed.
# However we need to point the build system at the stock prebuilts for boot + dtbo + vendor.img
TARGET_PREBUILT_KERNEL := device/infinix/X657B/prebuilts/kernel
TARGET_PREBUILT_DTB    := device/infinix/X657B/prebuilts/dtb

# Filesystem
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Init scripts (fstab + boot helpers)
PRODUCT_PACKAGES += \
    fstab.mt6761

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.mt6761:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6761

# Low-RAM tuning (matches stock Go config)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.low_ram=true \
    ro.lmk.use_psi=true

# Audio + camera HAL config defaults (LineageOS Go defaults are fine, no overrides needed)
