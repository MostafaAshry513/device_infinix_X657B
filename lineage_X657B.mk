# Inherit AOSP device configuration for X657B (32-bit Android Go)
$(call inherit-product, device/infinix/X657B/device.mk)

# Inherit LineageOS GO variant (low-RAM optimized minimal app set)
$(call inherit-product, vendor/lineage/config/common_mini_go_phone.mk)

PRODUCT_NAME := lineage_X657B
PRODUCT_DEVICE := X657B
PRODUCT_BRAND := Infinix
PRODUCT_MODEL := Infinix Smart 5
PRODUCT_MANUFACTURER := INFINIX

PRODUCT_GMS_CLIENTID_BASE := android-transsion

# Match stock build descriptor so SafetyNet basic profile matches
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="X657B-OP-S2 11 RP1A.200720.011 221121V777 release-keys"

BUILD_FINGERPRINT := Infinix/X657B-OP-S2/Infinix-X657B:11/RP1A.200720.011/221121V777:user/release-keys

TARGET_VENDOR := Infinix
TARGET_VENDOR_PRODUCT_NAME := X657B
