# X657B LineageOS 18.1 — Working Build Recipe

After extensive debugging, our hand-made device tree hit an unloggable early-init
watchdog hang. The reliable path is the **mature community device tree** + the
**real vendor blob tree**, retargeted to LineageOS, with a few build-compat fixes.

## Sources (the key discovery)
- **Device:** `Miracleprjkt/Device_Infinix_X657B`  branch `LineageOS-18.1`  → `device/infinix/X657B`
- **Vendor:** `noophyy/vendor_infinix_X657B`        branch `eleven`         → `vendor/infinix/X657B`
- Uses the **prebuilt stock kernel** (in device `prebuilt/`) — identical to stock; kernel-from-source is NOT needed.

## local_manifests/x657b.xml
```xml
<manifest>
  <project name="Miracleprjkt/Device_Infinix_X657B" path="device/infinix/X657B" remote="github" revision="LineageOS-18.1" />
  <project name="noophyy/vendor_infinix_X657B" path="vendor/infinix/X657B" remote="github" revision="eleven" />
</manifest>
```

## Fixes applied (see device_X657B_lineage.patch / vendor_X657B_lineage.patch)
1. **lineage_X657B.mk**: inherit `vendor/lineage/config/common_full_phone.mk` (was `vendor/nusantara/...`); `PRODUCT_NAME := lineage_X657B`.
2. **device.mk**: comment out `vendor/mediatek/ims/*` inherits (IMS tree not present; VoLTE only).
3. **BoardConfig.mk**: super size 9126805504 → **3439329280** (this device's real super); error-limit likewise; add `BOARD_MAIN_SIZE := 3435134976`; add `DEVICE_MANIFEST_FILE` listing all vendor VINTF manifest fragments.
4. **X657B-vendor.mk** (vendor): remove `PRODUCT_COPY_FILES` lines that the LOS 18.1 build rejects — VINTF `manifest*.xml` (use DEVICE_MANIFEST_FILE), prebuilt `*.apk` (use BUILD_PREBUILT), `compatibility_matrix*.xml`.

## Build
```
source build/envsetup.sh
lunch lineage_X657B-eng
mka -j<N> systemimage vendorimage productimage systemextimage
# then assemble super.img sized to 3439329280 with lpmake (system+system_ext+vendor+product, group "main")
```

## Flash (TWRP + ADB)
- `simg2img super.img /dev/block/by-name/super`   (super is sparse)
- Keep stock boot or flash the tree's prebuilt-kernel boot.img (cmdline must stay short: `androidboot.selinux=permissive`)
- Zero vbmeta/vbmeta_system/vbmeta_vendor (AVB off)
- Wipe cache+dalvik; first boot does ART compile (5-15 min)

## Why our original hand-made tree failed
Minimal Go tree lacked device-specific `init_X657B.cpp`, HALs, correct kernel base/offsets
(0x40078000) and cmdline (bootopt=64S3,32N2,64N2). It hung in early init before any
`.rc` ran, with no panic (watchdog reset wipes the log → undiagnosable). The mature tree
ships all those device-specific pieces.
