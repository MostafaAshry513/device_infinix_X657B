# LineageOS 18.1 device tree — Infinix Smart 5 (X657B)

Unofficial LineageOS 18.1 device tree for the **Infinix Smart 5 (X657B / X657B-OP-S2)**, a MediaTek MT6761 (Helio A22) device running 32-bit Android 11 Go.

This tree builds a flashable ROM that ships **fresh LineageOS `system` + `system_ext`** on top of **stock `vendor` + `product` + `boot` + `dtbo`** for maximum hardware compatibility — no kernel modifications, no vendor blob extraction, no risk of breaking device-specific drivers (camera, fingerprint, modem, etc.).

## Device specs

| Item | Value |
|---|---|
| Codename | X657B |
| Model | Infinix Smart 5 |
| SoC | MediaTek MT6761 (Helio A22) |
| CPU | Quad-core ARM Cortex-A53 @ 2.0 GHz, 32-bit |
| GPU | PowerVR Rogue GE8320 |
| RAM | 2 GB (Android Go config) |
| Storage | 32 GB eMMC |
| Display | 6.6" HD+ (1600×720), 320 DPI |
| Android | 11 / Go Edition |

## Build prerequisites

You will need a working LineageOS 18.1 source tree (see [LineageOS docs](https://wiki.lineageos.org/devices/X657B/build)).

This device tree depends on:
- `vendor/infinix/X657B` — companion vendor tree (this repo's sibling; provides stock `vendor.img` and `product.img` as prebuilts)
- `kernel/infinix/mt6761` — kernel source (not strictly required; we use stock prebuilt kernel)

## Setup

Place this repo in your LineageOS source tree at `device/infinix/X657B`:

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
python3 tools/unpack_bootimg.py --boot_img stock/boot.img --out stock/boot-unpacked/

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
2. Wipe **Dalvik / ART Cache** and **Cache** only.
3. **Install** the ROM ZIP. The flash will replace `system` + `system_ext` only; `vendor` and `product` get re-flashed with their stock images (no-op effectively).
4. Reboot. First boot takes 5-15 min (apps dexopt on first launch).

## Known limitations / TODO

- **OTG** not enabled in stock kernel — requires kernel rebuild with `CONFIG_USB_OTG=y`. See companion kernel repo.
- **VoLTE / VT** depends on modem firmware; YMMV.
- **First-boot bootloop** with the current `vbmeta` flags 3 disable — if you hit verified-boot rejection, flash an empty disable-verity vbmeta to `vbmeta` / `vbmeta_system` partitions.

## Credits

- TWRP device tree generator output by @SebaUbuntu — used as a reference for kernel addresses and architecture flags ([source](https://github.com/twrpdtgen/android_device_infinix_Infinix-X657B))
- Stock firmware images from official Infinix releases.

## License

Apache 2.0 — see [LICENSE](LICENSE).
