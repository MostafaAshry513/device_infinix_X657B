# BoardConfig for Infinix X657B (MT6761 Helio A22, 32-bit Android Go).
# Strategy: ship LineageOS system/system_ext; reuse stock vendor + product + boot + dtbo.
#
# Device-specific values (kernel addresses, ABI, etc.) verified against
# https://github.com/twrpdtgen/android_device_infinix_Infinix-X657B (TWRP DT generator output).

DEVICE_PATH := device/infinix/X657B

# Architecture — 32-bit ARM Cortex-A53, but 64-bit binder for Treble
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_USES_64_BIT_BINDER := true

# APEX — flatten for low-RAM Go config + makes boot.art live in flat /system/framework
# instead of inside an APEX bundle (which we don't ship).
OVERRIDE_TARGET_FLATTEN_APEX := true

# Disable dexpreopt entirely — apps will compile on first launch.
# Only allowed on eng build variant (user/userdebug require dexpreopt).
WITH_DEXPREOPT := false

# Platform / bootloader
TARGET_BOARD_PLATFORM := mt6761
TARGET_BOOTLOADER_BOARD_NAME := Infinix-X657B
TARGET_NO_BOOTLOADER := true

# Display
TARGET_SCREEN_DENSITY := 320

# Kernel + boot.img layout (verified against stock boot.img unpack)
BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_KERNEL_BASE        := 0x40000000
BOARD_KERNEL_PAGESIZE    := 2048
BOARD_RAMDISK_OFFSET     := 0x11b00000
BOARD_KERNEL_TAGS_OFFSET := 0x07880000
BOARD_KERNEL_CMDLINE     := bootopt=64S3,32S1,32S1 buildvariant=user
BOARD_KERNEL_IMAGE_NAME  := Image
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)

# Use stock kernel + DTB as prebuilts (we are not rebuilding the kernel for the first ROM)
TARGET_FORCE_PREBUILT_KERNEL := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilts/kernel
TARGET_PREBUILT_DTB    := $(DEVICE_PATH)/prebuilts/dtb
BOARD_MKBOOTIMG_ARGS  += --dtb $(TARGET_PREBUILT_DTB)
BOARD_INCLUDE_DTB_IN_BOOTIMG :=
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilts/dtbo.img
BOARD_KERNEL_SEPARATED_DTBO :=

# Filesystem
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE   := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE   := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE  := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext

# Partitions (sizes from actual lpunpack of stock super.img — 4 logical partitions)
BOARD_BOOTIMAGE_PARTITION_SIZE     := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 40894464
BOARD_DTBOIMG_PARTITION_SIZE       := 8388608

BOARD_SUPER_PARTITION_SIZE := 3400384512
BOARD_SUPER_PARTITION_GROUPS := infinix_dynamic_partitions
BOARD_INFINIX_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext vendor product
BOARD_INFINIX_DYNAMIC_PARTITIONS_SIZE := 3396190208

BOARD_SYSTEMIMAGE_PARTITION_SIZE     := 1610612736
BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE := 1073741824
BOARD_PRODUCTIMAGE_PARTITION_SIZE    := 1610612736
BOARD_VENDORIMAGE_PARTITION_SIZE     := 369098752

# Stock prebuilt images — we do not rebuild vendor or product (they get shipped as-is)
BOARD_PREBUILT_VENDORIMAGE  := vendor/infinix/X657B/prebuilts/vendor.img
BOARD_PREBUILT_PRODUCTIMAGE := vendor/infinix/X657B/prebuilts/product.img

# AVB / Verified Boot
# Disable verification + hashtree (flags 3) so modified LineageOS system passes
# stock fstab's dm-verity check. Non-A/B devices building recovery need
# RECOVERY signing keys defined.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

BOARD_AVB_VBMETA_SYSTEM := system
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 2

# PLATFORM_SECURITY_PATCH must be set via build env / overlay, not in BoardConfig (it is readonly).
# Use the LineageOS-default + only override VENDOR_SECURITY_PATCH to bypass anti-rollback.
VENDOR_SECURITY_PATCH := 2099-12-31

# Recovery — let the build produce its own recovery.img (we don't flash it; user
# keeps TWRP). Building it ensures recovery_fstab gets set, which is required for
# INTERNAL_OTA_PACKAGE_TARGET to be defined and the bacon target to succeed.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab

# Treble — required on Android 11+
BOARD_VNDK_VERSION := current
PRODUCT_FULL_TREBLE_OVERRIDE := true

# SELinux — start with device-specific policy stubs in /sepolicy
BOARD_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy

# Inherit LineageOS BoardConfig common kernel bits
include vendor/lineage/config/BoardConfigKernel.mk
