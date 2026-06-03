# Build-14 — OTG + TWRP-survival (stock kernel, custom kernel dropped)

**Date:** 2026-06-03  ·  **Base:** booting build-13 (LineageOS 18.1, MT6761, flattened APEX, enforcing)

## Why this build
User goal reduced to two concrete fixes (and on success, the custom-kernel effort is dropped):
1. **OTG / USB host** must work.
2. **Custom recovery (TWRP) must survive reboots** — stock setup was re-flashing stock recovery on boot.

Both turned out to be **ROM/userspace fixes — no custom kernel needed.**

## Fix 1 — OTG (USB host)
- Stock kernel **already supports OTG**: `CONFIG_USB_MTK_HDRC=y`, `CONFIG_DUAL_ROLE_USB_INTF=y`,
  `CONFIG_MTK_MUSB_QMU_SUPPORT=y`. Stock vendor is OTG-ready: USB HAL
  `android.hardware.usb@1.1-service-mediatekv2`, fstab `voldmanaged=usbotg:auto`, `/storage/usbotg` mounts.
- **Root cause:** the ROM declared **no `android.hardware.usb.*` feature** at all, so the framework's
  `UsbHostManager` never enabled host mode.
- **Change (`device.mk`):** added
  `android.hardware.usb.host.xml` + `android.hardware.usb.accessory.xml` to `PRODUCT_COPY_FILES`
  (-> `/system/etc/permissions/`). Verified present in `system.img` with `system_file` label.

## Fix 2 — TWRP survival
- **Root cause:** `/vendor/etc/init/vendor_flash_recovery.rc` runs `vendor_flash_recovery` ->
  `/vendor/bin/install-recovery.sh`, which on every boot re-patches recovery back to stock from
  `/vendor/recovery-from-boot.p` when it detects a non-stock recovery (TWRP).
- **Change (patched into `vendor_v14.img`):** replaced `install-recovery.sh` with a no-op (`exit 0`).
  SELinux label preserved (`vendor_install_recovery_exec`). `recovery-from-boot.p` left in place (unused).

## Also in vendor_v14 (low_ram)
- `ro.config.low_ram=true` -> `false` (normal Android 11: split-screen / multi-window).
  build.prop SELinux label restored to `u:object_r:vendor_file:s0` on-disk via debugfs (sed -i had
  dropped it — host has no SELinux so getfattr couldn't see it; verified with debugfs ea_get/ea_set).

## ROM contents (unchanged from build-14 spec)
- Lawnchair launcher (priv-app), gesture nav default, status-bar clock cutout fix, debloat.
- **Known leftover:** `Seedvault` + `Updater` survived the `filter-out` debloat (harmless; can strip later).

## Kernel decision
Custom from-source kernel **dropped** — not feasible: Infinix never released X657B kernel source; the
generic MT6761 tree is missing the `nt36525b` display panel driver + 75 `CONFIG_TRAN_*` hooks, so it boots
but the screen stays dark. Stock kernel (`boot` md5 `57e6f9de…`) is required and supports everything needed.

## Artifacts (Mega: /X657B-build/roms/build-14/)
| file | md5 |
|------|-----|
| super_v14.img (system+system_ext+product+vendor_v14) | `8b81afbab8ca1e18f2a4016ba4a5bd70` |
| boot_stock_WORKING.img | `57e6f9defa78bb11c042a9f7b4c68a71` |
| vbmeta.img / vbmeta_system / vbmeta_vendor | flags=3 (AVB disabled) |

Flash: TWRP -> `simg2img super_v14.img` to `by-name/super`; `dd` boot + vbmeta; Format Data; reboot.
