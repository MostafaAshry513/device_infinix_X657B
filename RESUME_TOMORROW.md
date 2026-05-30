# X657B LineageOS — RESUME POINT (pause for the day)

## STATE: boots through ALL of first-stage mount; dies at switch_root
Latest fresh log (boot_nocheck + super_v5 + proper vbmeta):
  init first stage started -> /metadata mounted -> dm-0(system) dm-1(system_ext) dm-2(vendor)
  dm-3(product) ALL mounted -> Kernel panic "Attempted to kill init" exitcode=0x00007f00 @1.41s
  (e2fsck error is GONE after removing `check` from first-stage fstab.)
exitcode 0x7f00 = switch_root failure ("Unable to move mount ..." — not captured in ramoops window).
This is the LAST first-stage step. We've cleared: ramdisk load, vbmeta, all 4 mounts, e2fsck.

## CURRENT ON-PHONE STATE
- boot = boot_nocheck.img (stock 742K ramdisk, fstab first-stage `check` removed, cmdline
  "bootopt=64S3,32S1,32S1 buildvariant=user" [SELinux ENFORCING — no room for permissive])
- super = super_v5 (full LOS system+system_ext+product + stock no-encryption vendor) WITH:
    * /vendor + /system_ext mountpoints added (via mount -o context=u:object_r:rootfs:s0 + mkdir)
    * /metadata + /product mountpoints (already present)
    * a debug logger /etc/init/zz_blog.rc (dumps dmesg->/metadata/blog.txt) — REMOVE for final
    * TWRP e2fsck copied into /system/bin (harmless, unused now)
- vbmeta/vbmeta_system = build's proper disabled-vbmeta (flags 3, AVB0). vbmeta_vendor zeroed.

## NEXT STEPS (tomorrow)
1. Find WHY switch_root fails after all mounts. Likely the /vendor or /system_ext mountpoints I
   created have wrong SELinux label (rootfs:s0) so MS_MOVE onto them fails, OR /metadata move.
   -> Capture the exact "Unable to move mount at '<x>'" line (widen ramoops read, or it's at
      ~1.41s just before the panic).
2. Proper fix: bake the mountpoints into the build with correct contexts (BOARD_USES_METADATA_PARTITION
   handles /metadata; vendor/system_ext mountpoints + file_contexts). Then rebuild systemimage.
3. Consider: is switch_root even needed here, or is the move target the issue. Compare with how the
   GSI (which boots) handles first-stage on this device.
4. Once first-stage passes -> second-stage init runs -> /metadata/blog.txt will finally populate
   (logger is installed) -> debug second-stage from there.

## KEY DEVICE FACTS (hard-won)
- cmdline MUST keep `bootopt=64S3,32S1,32S1` (MTK LK won't load ramdisk otherwise -> "unable to
  mount root fs"). Budget ~40 chars so can't also fit androidboot.selinux=permissive.
- Use build's disabled-vbmeta (flags 3), NOT zeroed (zeros = invalid AVB struct).
- System image needs empty mountpoints /metadata /vendor /system_ext /product for switch_root.
- Don't repack boot with abootimg (breaks ramdisk); use build's mkbootimg.
- ramoops only commits on PANIC (not watchdog). Logger->/metadata for non-panic stages.
- Proven tree: Miracleprjkt/Device_Infinix_X657B (LineageOS-18.1) + noophyy/vendor_infinix_X657B (eleven).
- Build dir: /root/android/lineage  (lunch lineage_X657B-eng)

## ARTIFACTS
- GitHub: MostafaAshry513/device_infinix_X657B (BUILD_FIXES.md, WORKING_BUILD_RECIPE.md, patches)
- Mega: /X657B-build/roms/build-8-proven-tree/ (super.img, boot_nocheck.img, vbmeta*, FLASH.md, BUILD_FIXES.md)
