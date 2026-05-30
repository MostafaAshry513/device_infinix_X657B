# X657B LineageOS 18.1 — Build-error fixes (proven tree: Miracleprjkt device + noophyy vendor)

Sequence of build errors hit and fixed when retargeting the community tree to LOS 18.1.
Build env: 8-core server, -j8, ALLOW_MISSING_DEPENDENCIES=true.

1. **Product retarget** — lineage_X657B.mk inherited `vendor/nusantara/...` → changed to
   `vendor/lineage/config/common_full_phone.mk`; PRODUCT_NAME nad_X657B → lineage_X657B.

2. **Missing vendor/mediatek/ims** — device.mk inherited mtk-ims.mk / mtk-engi.mk (not synced).
   Commented out (IMS = VoLTE, not boot-critical).

3. **Super size** — tree assumed a repartitioned 9.1 GB super; this device's real super is
   3,439,329,280 B. Set BOARD_SUPER_PARTITION_SIZE + ERROR_LIMIT to that, BOARD_MAIN_SIZE=3,435,134,976.

4. **VINTF manifests in PRODUCT_COPY_FILES** — LOS 18.1 build forbids it. Removed the
   SIM-variant `manifest_*.xml` copies, moved the 18 vendor HAL manifest fragments to
   `DEVICE_MANIFEST_FILE` (which merges them), removed `compatibility_matrix*.xml` copies.

5. **Prebuilt .apk in PRODUCT_COPY_FILES** — build wants BUILD_PREBUILT. Deleted the
   prebuilt-APK copy lines (overlays/apps, not boot-critical).

6. **init.mt6761.rc invalid keyword** — `tran_factory_reset` (Transsion builtin) at line 1188
   rejected by host_init_verifier. Commented out.

7. **Corrupt webview.apk** — external/chromium-webview prebuilts are Git-LFS; repo synced
   without LFS so they were 133-byte pointers → "failed opening zip". Installed git-lfs,
   cloned LineageOS/android_external_chromium-webview, copied real APKs
   (arm 52MB / arm64 95MB / x86 64MB / x86_64 104MB) into prebuilt/<abi>/webview.apk.

See device_X657B_lineage.patch + vendor_X657B_lineage.patch for exact diffs.

---
## build-8: full proven-tree LOS flashed — still early-init hang
- Built full LineageOS from Miracleprjkt device + noophyy vendor (system 728M, system_ext 202M,
  product 250M, boot 32M). Used stock no-encryption vendor_fixed.img (noophyy blobs == this
  device's stock vendor). Assembled super_v5 (1.5G sparse, fits 3.4G easily). On Mega: build-8-proven-tree.
- Flashed boot + super_v5 + (initially zeroed) vbmeta. Result: static Infinix logo ~15-20s then
  watchdog loop — IDENTICAL to our hand-made tree. => the hang is NOT the ROM content; it's our
  DEPLOYMENT (we hit it even with a known-working tree).
- KEY: we had ZEROED vbmeta every attempt. Proven tree builds system WITH avb (flags 3 = disabled).
  Flashed the BUILD's proper disabled-vbmeta (magic AVB0, not zeros) instead.
  => boot time CHANGED 20s -> 10s (vbmeta definitely on the critical path).
- TWRP also logs: "unable to load apex from /system_root/system/apex" (likely benign TWRP APEX limitation).
- NEXT: read ramoops after the 10s loop (shorter time may = a real panic now, which commits to pstore).

---
## BREAKTHROUGH (fresh ramoops log!): proven-tree boot.img has an EMPTY ramdisk
With proper vbmeta flashed, boot now PANICS at ~2.2s (not silent watchdog) -> ramoops finally
committed a real log:
  panic -> mount_block_root -> mount_root -> prepare_namespace  (cmdline root=/dev/ram)
= kernel cannot mount root fs (no initramfs).
Boot.img header compare:
  stock boot.img    ramdisk size = 742970 bytes (real first-stage ramdisk)
  proven-tree boot  ramdisk size = 3304 bytes  (EMPTY - no first-stage init!)
=> The Miracleprjkt tree build produced a boot.img with no usable ramdisk (build-config quirk;
   likely expects a prebuilt/recovery-as-boot ramdisk not wired in our setup).
FIX: use the working STOCK ramdisk (stock boot.img / boot-final) which DOES contain first-stage
init (proven: it runs init to ~25s). Pair stock ramdisk + full-LOS super_v5 + proper disabled-vbmeta.
Note: this also means our earlier ~25s hangs were with a WORKING ramdisk (init running) - the real
remaining question is the 25s init hang, now retested with full LOS + proper vbmeta.

---
## DEEP DIVE: "VFS: Unable to mount root fs" — ramdisk/initramfs not loading
With proper vbmeta we get fresh ramoops on each fail. Definitive panic:
  [EXFAT] trying to mount...
  Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(1,0)
unknown-block(1,0) = /dev/ram0. Kernel never received the ramdisk as initramfs; it falls back to
mounting root=/dev/ram0 as a raw block device, finds no fs, panics. So second-stage init never runs
(our /etc/init logger never produces /metadata/blog.txt -> confirms first-stage/pre-init failure).

Boot.img ramdisk audit (gzip cpio, NO MTK ROOTFS header on this device):
- stock boot.img:    ramdisk 742970 B (real, OEM)  -> SHOULD load
- los_boot_v5 (built from Miracleprjkt tree): ramdisk 3304 B (EMPTY) -> can't mount root
- boot-final (abootimg-repacked long ago): ramdisk broken -> can't mount root

Findings:
- vbmeta: ZEROED is better than the build's "disabled" vbmeta here. Proper vbmeta_system made
  first-stage attempt AVB/verity and fail even earlier; zeroed = AVB fully off.
- Even a CLEAN stock 742K ramdisk + cmdline patched to "androidboot.selinux=permissive" still
  mount_root-panics. Suspect: replacing stock cmdline dropped "bootopt=64S3,32S1,32S1" — the MTK
  boot param that governs ramdisk/root setup. Removing it appears to break initramfs loading.
- NOW TESTING: pristine unmodified stock boot (full cmdline incl bootopt) to confirm the ramdisk
  loads. If it loads -> bootopt is required -> must keep bootopt AND fit selinux=permissive (cmdline
  budget is tight; bootloader "cmdline overflow" >~40 chars of our portion).

---
## DISCOVERY: bootopt= is REQUIRED in cmdline (controls ramdisk/root load on MTK LK)
- Pristine stock cmdline "bootopt=64S3,32S1,32S1 buildvariant=user" (40ch) -> ramdisk LOADS, no
  mount_root panic. Replacing it with only "androidboot.selinux=permissive" (no bootopt) -> ramdisk
  does NOT load -> "Unable to mount root fs". => bootopt is mandatory for the MTK bootloader to set
  up the initramfs/root.
- PROBLEM: cmdline budget ~40 chars (LK "cmdline overflow" beyond that). Can't fit BOTH
  "bootopt=64S3,32S1,32S1" (22) AND "androidboot.selinux=permissive" (30) = 53ch. So with bootopt
  we currently run SELinux ENFORCING (no permissive).
- With pristine boot (bootopt, working ramdisk) + ZEROED vbmeta: no panic, no second-stage
  (logger /metadata/blog.txt empty) => FIRST-STAGE hang. Suspect zeroed vbmeta = invalid AVB struct
  that stalls the stock first-stage AVB; the build's flags-3 vbmeta is a VALID "disabled" descriptor.
- NEXT: pristine stock boot + build's proper disabled-vbmeta (flags 3) + logger system. If first
  stage cleanly skips AVB -> should reach second-stage (blog.txt appears).

---
## BIG PROGRESS: working ramdisk + bootopt + proper vbmeta -> first-stage init RUNS
Fresh log (panics:1, cmdline has bootopt):
  init: init first stage started!
  mount /metadata (md_udc) OK
  EXT4-fs (dm-0): mounted filesystem  <- system mounted
  Kernel panic - Attempted to kill init! exitcode=0x00007f00  @1.376s
exitcode 0x7f00 == the original switch_root "/metadata" failure signature. So now EVERYTHING else
works (ramdisk load, first-stage init, /metadata mount, system mount) and we're back to the
switch_root-moves-/metadata-into-/system/metadata step. Checking if /system/metadata exists in
super_v5's system; if missing, add it (ext4 surgery) -> switch_root should pass -> second-stage.

---
## FIX: system root was missing /vendor and /system_ext mountpoints
super_v5 system had /metadata + /product but NOT /vendor or /system_ext. First-stage mounts all
logical partitions (system_ext, vendor, product) + /metadata then switch_root moves them into
/system/<x>; missing /system/vendor (and /system_ext) -> switch_root "Unable to move mount" ->
init killed (exitcode 0x7f00). Created the two missing mountpoint dirs via
`mount -o rw,context=u:object_r:rootfs:s0` + mkdir (recovery SELinux blocks default mkdir).
Now all of /vendor /system_ext /product /metadata exist; e2fsck clean. Rebooting:
pristine stock boot (bootopt, working ramdisk) + proper vbmeta + this system.

---
## NEAR-BOOT: all 4 logical partitions mount; init dies on MISSING /system/bin/e2fsck
After creating /vendor + /system_ext mountpoints, fresh first-stage log shows:
  mount /metadata OK; EXT4 dm-0(system) dm-1(system_ext) dm-2(vendor) dm-3(product) ALL mounted!
  e2fsck: executing /system/bin/e2fsck failed: No such file or directory
  e2fsck: e2fsck terminated by exit(255)
  Kernel panic - Attempted to kill init! exitcode=0x00007f00  @1.207s
=> A `check`-flagged fstab partition makes fs_mgr run /system/bin/e2fsck, which is ABSENT from the
   built system -> exit 255 -> init fatal. FIX: provide e2fsck in /system/bin (PRODUCT_PACKAGES += e2fsck)
   OR remove `check` from fstab. Quick on-phone fix: drop a working/stub e2fsck into the system.

---
## e2fsck fix attempt + Mega-mirror habit
/system/bin/e2fsck EXISTS in the LOS system but fails to exec at first-stage ("No such file or
directory" = its dynamic linker not resolvable pre-switch_root). Swapped in TWRP's e2fsck (interp
/system/bin/linker, which the LOS system provides) onto dm-0:/system/bin/e2fsck + /bin/e2fsck.
If it still fails, robust fix = remove `check` flag from the first-stage (ramdisk) fstab partition
(likely /tranfs) so fs_mgr never runs e2fsck pre-switch_root, OR ship a STATIC e2fsck.
(All four logical partitions already mount; this e2fsck step is the last first-stage blocker.)

---
## e2fsck swap FAILED (TWRP e2fsck also dynamic /system/bin/linker, unresolvable first-stage)
Same panic. ROBUST FIX: repack the boot ramdisk to remove `check` from first-stage fstab entries
(so fs_mgr never invokes e2fsck pre-switch_root). Repack with the BUILD's mkbootimg (NOT abootimg,
which produced a broken ramdisk earlier), preserving exact stock header:
  base=0x40000000 kernel_off=0x8000 ramdisk_off=0x11b00000 tags_off=0x7880000 pagesize=2048 hdrv2,
  cmdline keeps "bootopt=64S3,32S1,32S1", dtb from stock.

---
## FIX: repacked boot.img with `check` removed from first-stage fstab (/metadata,/tranfs)
Used build's mkbootimg (stock header: base 0x40000000, k_off 0x8000, rd_off 0x11b00000,
tags 0x7880000, pg 2048, hdrv2, cmdline "bootopt=64S3,32S1,32S1 buildvariant=user", stock dtb).
Real 742554-byte ramdisk preserved. Now fs_mgr won't run e2fsck pre-switch_root.
File: boot_nocheck.img. Flashing with super_v5(+mountpoints) + proper vbmeta.
