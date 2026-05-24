# Infinix X657B — Hardware specifications (extracted from stock firmware)

Every value below was extracted from the stock firmware files for this exact device. Sources are cited.

## Identity

| Item | Value | Source |
|---|---|---|
| Codename | `X657B` | `MT6761_Android_scatter.txt` (project: `x657b_h6117`) |
| Marketing name | Infinix Smart 5 | `ro.product.vendor.model = Infinix X657B` |
| Internal product | `X657B-OP-S2` | `ro.product.vendor.name` |
| OS variant | TSSI / Android Go 32-bit | `ro.build.flavor = sys_tssi_32_ago_infinix_q_ota-user` |
| Display ID | `INFINIX-RGo-32-221121V701` | `ro.build.display.id` |
| Vendor fingerprint | `Infinix/X657B-OP-S2/Infinix-X657B:11/RP1A.200720.011/221121V777:user/release-keys` | `ro.vendor.build.fingerprint` |
| Manufacturer | INFINIX MOBILITY LIMITED | `ro.product.vendor.manufacturer` |

## SoC + CPU

| Item | Value | Source |
|---|---|---|
| Chipset | MediaTek MT6761 | `ro.board.platform`, DTB `compatible = "mediatek,MT6761"` |
| Architecture | ARMv7-A NEON, 32-bit | DTB cmdline `androidboot.hardware=mt6761`, `ro.product.cpu.abi=armeabi-v7a` |
| Primary ABI | `armeabi-v7a` | `ro.product.cpu.abi` |
| Secondary ABI | `armeabi` | `ro.product.cpu.abi2` |
| 64-bit ABI | (none — pure 32-bit) | `ro.product.cpu.abilist64=` (empty) |
| Max CPUs | 8 | DTB cmdline `maxcpus=8` (actual quad-core on this SoC; bootloader caps higher) |
| Vendor SDK level | 30 (Android 11) | `ro.vendor.build.version.sdk` |
| First API level | 29 (Android 10) | `ro.product.first_api_level` |

## Memory

| Item | Value | Source |
|---|---|---|
| RAM | 3 GB | device owner (verified — DTB has placeholder values overridden by bootloader) |
| RAM type | **LPDDR4 / LPDDR4X** | DTBO regulators: `ext_buck_lp4`, `ext_buck_lp4x` |
| Low-RAM config | Enabled | `ro.config.low_ram = true` |
| Dalvik heap (max) | 256 MB | `dalvik.vm.heapsize` |
| Dalvik heap (growth limit) | 128 MB | `dalvik.vm.heapgrowthlimit` |
| vmalloc | 400 MB | DTB cmdline `vmalloc=400M` |

## GPU

| Item | Value | Source |
|---|---|---|
| EGL vendor | `meow` (Imagination Technologies internal codename) | `ro.hardware.egl` |
| Graphics composer HAL | 2.1 | `vendor/etc/vintf/manifest.xml` |
| Graphics allocator | 4.0 (Gralloc4) | `vendor/etc/vintf/manifest.xml` |
| Renderscript | armeabi-v7a path | (32-bit) |

## Display

| Item | Value | Source |
|---|---|---|
| Density | 320 DPI | `ro.sf.lcd_density` |
| Panel | **Novatek NT35521** | DTBO `atag,videolfb-lcmname = "nt35521_hd_dsi_vdo_truly_rt5081_drv"` |
| Panel resolution class | HD (likely 720×1600 HD+) | LCM string contains `hd` |
| Interface | MIPI DSI (video mode) | LCM string contains `dsi_vdo` |
| Panel manufacturer | Truly Semiconductors | LCM string contains `truly` |
| Display PMU | Richtek RT5081 | LCM string contains `rt5081` |
| Refresh rate | 60 fps (likely) | DTBO `atag,videolfb-fps = 0x1770` = 6000 / 100 = 60Hz |
| Surface flinger HWC copy | enabled | `ro.surface_flinger.force_hwc_copy_for_virtual_displays = true` |

## Touchscreen

| Item | Value | Source |
|---|---|---|
| Touch IC | **Novatek** (factory variant) — possibly Goodix GT1151 in some units | DTBO `compatible = "novatek-mp-criteria-6229..624a"`; vendor firmware `novatek_ts_fw*.bin`, `gt1151_default_firmware2.img` |
| Driver | Capacitive touch via MTK driver | DTBO `compatible = "mediatek,cap_touch"` |

## Storage

| Item | Value | Source |
|---|---|---|
| Type | eMMC | scatter file `storage: EMMC, boot_channel: MSDC_0` |
| /data filesystem | F2FS (with hardware inline crypt) | fstab |
| /system, /vendor, /product, /system_ext | ext4 (logical / dynamic) | fstab |
| Super partition size | 3.4 GB (3,400,384,512 bytes) | from `lpunpack` of stock `super.img` |
| /data encryption | FBE: aes-256-xts (file content) + aes-256-cts (filename) v1 | fstab `fileencryption=aes-256-xts:aes-256-cts:v1` |

## Camera

| Item | Value | Source |
|---|---|---|
| Rear cameras | Two (main + secondary) | DTBO nodes `camera_main`, `camera_main_two` |
| Rear main features | Autofocus + EEPROM | DTBO `camera_main_af`, `camera_main_eeprom` |
| Front cameras | Two (main + secondary) | DTBO nodes `camera_sub`, `camera_sub_two` |
| ISP | MTK ISP3 | `ro.vendor.camera.isp-version.major = 3` |
| Camera HAL | 2.6 (HIDL) | `vendor/etc/vintf/manifest.xml` |
| ZSL default | 140 ms | `ro.vendor.camera3.zsl.default = 140` |
| Flash | Strobe (LED) | DTBO `mediatek,strobe_main` |

## Modem / Cellular

| Item | Value | Source |
|---|---|---|
| Modem | MT6761 integrated (MOLY firmware) | `md1img.img`, `MDDB_InfoCustomAppSrcP_MT6761_S00_MOLY_LR12A_R3_MP_V149_4_P60_1_ulwtg_n.EDB` |
| Modem build | `LR12A_R3_MP_V149_4_P60_1` | MDDB filename |
| Network support | UMTS / LTE / WCDMA / TDS-CDMA / GSM | MDDB suffix `ulwtg_n` |
| SIM count | Dual (SIM1 hot-plug) | DTBO `mediatek,md1_sim1_hot_plug_eint`, `vsim1` + `vsim2` regulators |
| VoLTE | Supported (vendor HAL) | `vtservice_hidl`, `vendor.mediatek.hardware.mms` |

## Wi-Fi / Bluetooth / FM

| Item | Value | Source |
|---|---|---|
| Combo chip | **MediaTek MT6631** | `vendor/firmware/mt6631_fm_v1_*.bin`, soc1/soc3 firmware variants |
| Wi-Fi HAL | 1.0 | `vendor/etc/vintf/manifest.xml` |
| Wi-Fi interface | `wlan0` (sta), `ap0` (hotspot), `p2p0` (direct) | `system/build.prop`, `vendor/build.prop` |
| Bluetooth HAL | 1.0 | `vendor/etc/vintf/manifest.xml` |
| BT audio HAL | 2.0 | `vendor/etc/vintf/manifest.xml` |
| FM radio | Yes (via MT6631) | firmware presence |

## Audio

| Item | Value | Source |
|---|---|---|
| Audio HAL | 6.0 | `vendor/etc/vintf/manifest.xml` |
| Audio effect HAL | 6.0 | `vendor/etc/vintf/manifest.xml` |
| Audio codec | via MT6357 PMIC | DTB main_pmic = `mt6357` |
| Audio tuning tool ver | V2.2 | `ro.vendor.mtk_audio_tuning_tool_ver` |

## Sensors / Other

| Item | Value | Source |
|---|---|---|
| Sensors HAL | 2.0 | `vendor/etc/vintf/manifest.xml` |
| Sensors service | `mediatek-2.0` | `vendor/bin/hw/android.hardware.sensors@2.0-service-mediatek` |
| Fingerprint | **Transsion-branded** (sw/optical) over SPI 8MHz | DTBO `compatible = "tran_fp"`, `vendor.sw.swfingerprint@1.0-service` |
| NFC | Hardware present | DTBO `compatible = "mediatek,nfc"`, address `nfc@08` (may not be enabled in marketing) |
| GNSS | 1.1 + 2.1 (with LNA, FM coexistence) | manifest.xml, DTBO `gps_lna_state*` |
| USB | OTG-capable hardware | DTBO `mediatek,mtk-usb`, `mediatek,usb_type_c` (but stock kernel OTG disabled per device owner) |
| Vibrator | MediaTek vibrator AIDL | DTBO `mediatek,vibrator`, `android.hardware.vibrator-service.mediatek` |
| Notification LED | Red + Green (PWM) | DTBO `mediatek,red` + `mediatek,green` |
| Keymaster | 4.0 (Beanpod) | `vendor/bin/hw/android.hardware.keymaster@4.0-service.beanpod` |
| Gatekeeper | 1.0 (Beanpod) | `vendor/bin/hw/android.hardware.gatekeeper@1.0-service` |

## Power

| Item | Value | Source |
|---|---|---|
| PMIC | MediaTek MT6357 | DTB `main_pmic`, `mt6357-gauge` |
| Charger IC | MT6357 PMIC integrated + optional `slave_charger` | DTBO `mediatek,slave_charger` |
| Battery profile entries | 100 OCV points × 12 temp curves | DTB `battery0_profile_t0_num = 0x64`, plus t1-t11 |
| Battery overcurrent threshold (high) | 0x123e (4.670 V) | DTB `oc-thd-h` |
| Boot modes supported | normal, recovery, bootloader, dm-verity-corrupt, KPOC | DTB `mode-*` |

## Partition layout (stock)

| Partition | Type | Size (bytes) | Mount |
|---|---|---|---|
| `system` | ext4 logical | 624 MB (in super) | /system |
| `system_ext` | ext4 logical | 1014 MB (in super) | /system_ext |
| `vendor` | ext4 logical | 304 MB (in super) | /vendor |
| `product` | ext4 logical | 1332 MB (in super) | /product |
| `boot` | raw | 33,554,432 (32 MB) | boot |
| `recovery` | raw | 40,894,464 (~39 MB) | recovery |
| `dtbo` | raw | 8,388,608 (8 MB) | dtbo |
| `vbmeta` / `_system` / `_vendor` | AVB | 4,096 each | vbmeta* |
| `metadata` | ext4 | — | /metadata |
| `userdata` | F2FS | — | /data |
| `cache` | ext4 | — | /cache |
| `tranfs` | ext4 | — | /tranfs (Transsion-specific) |
| `protect1`, `protect2`, `nvdata`, `nvcfg`, `persist` | ext4 | small | /mnt/vendor/* |
| `frp` | raw | — | /persistent |

## Verified boot

| Item | Value | Source |
|---|---|---|
| AVB | Enabled | stock fstab `avb=vbmeta_system` and `avb` flags |
| GSI compatibility | Yes — accepts q/r/s-GSI signing keys | fstab `avb_keys=/avb/q-gsi.avbpubkey:/avb/r-gsi.avbpubkey:/avb/s-gsi.avbpubkey` |

## Sources

All values above were extracted from the official stock firmware ZIP (`INFINIX-SMART-5-X657B-H6117EIKL-RGo-OP-S2-221121V1102.zip`):

- `build.prop` (system / vendor / product / system_ext / odm)
- `boot.img` (DTB extracted via [extract-dtb](https://pypi.org/project/extract-dtb/) + `dtc`)
- `dtbo.img` (same)
- `vendor/etc/vintf/manifest.xml`
- `vendor/etc/init/*.rc`
- `vendor/firmware/*`
- `MT6761_Android_scatter.txt`
- `super.img` (split via `lpunpack`)
- `MDDB_InfoCustomAppSrcP_*.EDB` filename

The only spec NOT directly extractable from firmware files is **RAM size** (overridden by bootloader at runtime — DTB has 512 MB placeholder). RAM = 3 GB per the device owner.
