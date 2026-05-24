# LineageOS 18.1 device tree — Infinix Smart 5 (X657B)

Unofficial LineageOS 18.1 device tree for the **Infinix Smart 5 (X657B / X657B-OP-S2)**, a MediaTek MT6761 device running 32-bit Android 11 Go.

Strategy: ship **fresh LineageOS `system` + `system_ext`** on top of **stock `vendor` + `product` + `boot` + `dtbo`** for maximum hardware compatibility — no kernel modifications, no vendor blob extraction, no risk of breaking device-specific drivers (camera, fingerprint, modem, etc.).

## Device specs

Values verified from the stock firmware:

| Item | Value | Source |
|---|---|---|
| Codename | `X657B` | scatter file (`x657b_h6117`) |
| Model | Infinix Smart 5 | `ro.product.vendor.model` |
| SoC | MediaTek MT6761 (Helio A22) | `ro.board.platform` |
| CPU ABIs | `armeabi-v7a`, `armeabi` (32-bit only) | `ro.product.cpu.abilist` |
| GPU | PowerVR (Imagination — vendor codename "meow") | `ro.hardware.egl` |
| Android | 11 / Go Edition | `ro.build.version.sdk=30`, `ro.config.low_ram=true` |
| Display DPI | 320 | `ro.sf.lcd_density` |
| RAM | 3 GB | device owner |
| /data FS | F2FS with inline-crypt | stock fstab |
| /system, /vendor, /product, /system_ext | ext4, logical (dynamic) | stock fstab |
| Vendor security patch | 2022-11-05 | `ro.vendor.build.security_patch` |

📋 **Full hardware specs sheet → [SPECS.md](SPECS.md)** — everything below + panel chip, touch IC, modem firmware version, camera config, fingerprint chip, NFC, FM radio, PMIC, battery profile, boot modes, and partition layout. All values cited to the exact stock firmware file they were extracted from.

## Build prerequisites

You will need a working LineageOS 18.1 source tree (see [LineageOS docs](https://wiki.lineageos.org/devices/X657B/build)).

This device tree depends on:
- [`vendor/infinix/X657B`](https://github.com/MostafaAshry513/vendor_infinix_X657B) — companion vendor tree (provides stock `vendor.img` and `product.img` as prebuilts)

## Setup

```bash
cd ~/lineage-18.1
git clone https://github.com/MostafaAshry513/device_infinix_X657B device/infinix/X657B
git clone https://github.com/MostafaAshry513/vendor_infinix_X657B vendor/infinix/X657B
```

Extract stock prebuilts from your X657B firmware ZIP:

```bash
# 1. Get your INFINIX-SMART-5-X657B-...zip and unzip it
unzip your-stock-firmware.zip -d stock/

# 2. Convert super.img to raw, then split logical partitions
simg2img stock/super.img stock/super.raw.img
python3 /opt/lpunpack/lpunpack.py stock/super.raw.img stock/super-parts/

# 3. Unpack stock boot.img to get kernel + DTB
python3 system/tools/mkbootimg/unpack_bootimg.py --boot_img stock/boot.img --out stock/boot-unpacked/

# 4. Drop the files into the right places
cp stock/boot.img                      device/infinix/X657B/prebuilts/boot.img
cp stock/dtbo.img                      device/infinix/X657B/prebuilts/dtbo.img
cp stock/recovery.img                  device/infinix/X657B/prebuilts/recovery.img
cp stock/boot-unpacked/kernel          device/infinix/X657B/prebuilts/kernel
cp stock/boot-unpacked/dtb             device/infinix/X657B/prebuilts/dtb
cp stock/super-parts/vendor.img        vendor/infinix/X657B/prebuilts/vendor.img
cp stock/super-parts/product.img       vendor/infinix/X657B/prebuilts/product.img
```

## Build

```bash
source build/envsetup.sh
lunch lineage_X657B-userdebug
mka bacon
```

Output: `out/target/product/X657B/lineage-18.1-*-UNOFFICIAL-X657B.zip`

## Flash (TWRP)

1. Take a TWRP backup of your current setup first.
2. Wipe **Dalvik / ART Cache** and **Cache** only (do NOT wipe /data unless you want a clean install).
3. **Install** the ROM ZIP. The flash will replace `system` + `system_ext`; `vendor` and `product` get re-flashed with their stock images.
4. Reboot. First boot takes 5-15 min (apps dexopt on first launch).

## Known limitations / TODO

- **OTG** not enabled in stock kernel — requires kernel rebuild with `CONFIG_USB_OTG=y`. See companion kernel repo (TBD).
- **VoLTE / VT** depends on modem firmware; YMMV.
- **vbmeta verification** is disabled in this build (`flags 3` — both verification and hashtree disabled). If your bootloader rejects, manually flash an empty disable-verity vbmeta to `vbmeta` partition.

## Credits

- TWRP device tree generator output by @SebaUbuntu — reference for kernel addresses and architecture flags ([source](https://github.com/twrpdtgen/android_device_infinix_Infinix-X657B))
- Stock firmware images from official Infinix releases.

## License

Apache 2.0 — see [LICENSE](LICENSE).
