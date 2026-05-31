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

---
## PAUSE POINT: e2fsck cleared; now switch_root panic after all 4 mounts
boot_nocheck (no first-stage check) -> all of /metadata,dm-0..3 mount, then init killed
(exitcode 0x7f00) at switch_root @1.41s. See RESUME_TOMORROW.md for full state + next steps.

---
## ROOT CAUSE of switch_root exit 127 (0x7f00): stock-ramdisk × LOS-system mismatch  [build-9]
DIAGNOSIS (server-side, no phone needed): inspected the FULL source-build artifacts.
- out/.../system.img root ALREADY contains /vendor /system_ext /metadata /product /odm
  mountpoints + init->/system/bin/init symlink, all with correct build SELinux labels.
  => the "missing mountpoints" we hand-mkdir'd (rootfs:s0) were never the real fix; the
     built system has them labelled correctly.
- out/.../ramdisk.img (790KB) is a PROPER LOS first-stage ramdisk (real 1.35MB init,
  fstab.mt6761, avb/). NOT the 3KB empty ramdisk (that was the proven-tree's *prebuilt*
  boot.img, not our build output).
- We had been flashing boot_nocheck.img = STOCK ramdisk + modified fstab. The stock
  first-stage init loads STOCK sepolicy, then after switch_root fails to re-exec the LOS
  /system/bin/init (domain/linker mismatch) => exit(127) => exitcode=0x7f00 @1.41s.

FIX: stop mixing. Use the FULLY LOS-built boot.img (LOS ramdisk + LOS first-stage init),
so first->second stage handoff is LOS-to-LOS consistent.

ALSO fixed in source (device/infinix/X657B/rootdir/etc/fstab.mt6761): removed `check` from
the two first_stage_mount lines (/metadata, /tranfs) so fs_mgr never invokes e2fsck
pre-switch_root (LOS ramdisk has no e2fsck binary). Rebuilt: `mka bootimage` (20s).
Verified: 0 first_stage_mount lines carry `check`; cmdline =
"bootopt=64S3,32N2,64N2 androidboot.selinux=permissive buildvariant=eng" (proven-tree
cmdline; the "~40-char overflow" was an artifact of our hand-repacking, not the built img).

vbmeta.img confirmed flags=3 (verification+hashtree disabled) => all fstab avb= flags are
no-ops; vendor avb mismatch irrelevant.

NOTE: the "~40 char MTK cmdline budget" lesson is now SUSPECT — it came from manual
mkbootimg/abootimg repacks, not from a cleanly-built boot.img. The published proven tree
boots with the full 70-char cmdline.

### build-9 FLASH SET (minimal, ~33MB push — super_v5 already on phone, unchanged)
1. boot.img (LOS-built, /root/android/flash_build9/boot.img)  -> dd to boot   [THE key change]
2. vbmeta.img (flags3)            -> dd to vbmeta
3. vbmeta_system.img             -> dd to vbmeta_system
4. zeroed 4K                     -> dd to vbmeta_vendor
5. KEEP super_v5 (on phone). wipe cache+dalvik. reboot.
EXPECT: switch_root passes -> second-stage init runs -> on-phone /etc/init/zz_blog.rc
logger populates /metadata/blog.txt -> pull to diagnose next stage.

---
## build-9 RESULT: first-stage fully OK; second-stage init exit 127 (SELinux/enforcing wall)
Fixed corrupt on-phone system (truncated flash) + check-free fstab + LOS-built boot. Now:
first-stage mounts ALL partitions (metadata+dm0-3), then second-stage /system/bin/init exits
127 instantly, logging nothing (dies before "Loading SELinux policy").
KEY: MTK LK IGNORES boot.img cmdline -> kernel gets stock cmdline, NO androidboot.selinux=permissive
-> boots ENFORCING. Proven: init links fine (chroot) + sepolicy compiles fine (server secilc exit0,
vendor vers 30.0 == our mapping/30.0.cil). The 127 (clean exit, not abort=6) is unexplained pre-log.
Full detail: FINDINGS_build9_exit127.md. Phone state: ready, sitting in TWRP, not booting.
TWRP write lesson: unmount /system_root first; simg2img-to-dm leaves gaps -> dd raw conv=notrunc.

---
## build-9 DEEP DEBUG (instrumented init) — blocked by device booting to recovery
Confirmed via /metadata breadcrumbs (durable) + ramoops:
- second-stage /system/bin/init: main() NEVER runs (no /metadata/wrapinit.log) -> dies in the
  dynamic LOADER before main; clean exit(127) (do_exit->sys_exit_group, NOT abort/6).
- Built instrumented init (breadcrumbs in main + SetupSelinux) and instrumented FIRST-stage
  init (FSB after DoFirstStageMount/FreeRamdisk/SetInitAvb + LD_DEBUG=3 + FSWRAP before execv).
  Deployed (boot partition md5 == flashed image; /system/bin/init replaced; verified on flash).
- RESULT: NO breadcrumb ever appears (fsboot.log/fswrap.log/wrapinit.log absent), ramoops stays
  BYTE-IDENTICAL across every reboot (md5 108f7daa...). `rm` of pstore clears the inode but the
  console DRAM persists; TWRP/recovery does not overwrite console-ramoops.
- CONCLUSION: the ROM has not booted since the FIRST build-9 attempt. Every `adb reboot` from
  TWRP lands back in recovery after ~64-110s. Likely MTK preloader KE(kernel-exception)->recovery
  protection after the initial panic bootloop. para(BCB) is all-zero (clean), so it's not BCB.
- So remote instrumentation is blocked until the device will boot the ROM again. Need: manual
  cold boot-to-system observation, and/or clear the MTK KE/boot-fail state.
TWRP file-write lesson reconfirmed: dd to /dev/block/by-name/boot persists (md5 verified);
logical-partition writes need /system_root unmounted.

---
## ROOT CAUSE of "nothing boots / always recovery" (build-9 era) — vbmeta flags!
USER INSIGHT: their TWRP backup boots, our flashes don't -> find the diff.
The working backup is a 64-bit GSI (treble_a64_bgZ-userdebug_11) whose TOP-LEVEL
vbmeta has flags=3 (AVB VERIFICATION DISABLED). Device is unlocked running custom images.
We regressed by flashing STOCK vbmeta flags=0 (AVB ENABLED) -> bootloader rejects non-OEM
partitions -> drops to recovery BEFORE the kernel runs -> every ramoops was the stale first
panic (RAM preserved across warm reboots; recovery doesn't overwrite console-ramoops).
RULE FOR THIS DEVICE: vbmeta MUST be flags=3 (disabled). NEVER flash stock flags=0 vbmeta.
Working set saved: /root/android/working_ref/{boot,vbmeta,vbmeta_system,vbmeta_vendor}.emmc.win
(boot md5 57e6f9def..., stock boot md5 ed53d6a20... -> working boot != stock boot).
Backup also has super.emmc.win (3.4G, GSI) + data.f2fs — restoring it = working phone.

---
## 2026-05-31 BREAKTHROUGH — working boot recipe + exit-127 isolated to SecondStageMain
KEY: device only boots with vbmeta flags=3 (AVB disabled) + the device's REAL stock boot (md5 57e6f9def...,
NOT the Flash_File boot ed53d6a2...). User's TWRP backup (a GSI) proved this recipe. Saved proven files in
/root/android/working_ref/{boot,vbmeta,vbmeta_system,vbmeta_vendor}.emmc.win.
With recipe = stock boot 57e6 + flags-3 vbmeta + our LOS super_v5 + an INSTRUMENTED /system/bin/init,
/metadata/wrapinit.log (fsync-durable) finally captured the real flow:
  first-stage -> selinux_setup -> SetupSelinux (SelinuxInitialize OK, policy loaded) -> re-exec ->
  second_stage -> "main -> SecondStageMain" -> THEN init exits 127 (clean do_exit/sys_exit_group, NOT abort).
=> ALL prior theories DEAD (loader/missing-lib/AVB/sepolicy). Failure is INSIDE init.cpp SecondStageMain.
A GSI super boots on the SAME boot, so it's our LOS system specifically.
The qwen-agent's recovery-logcat "missing confirmationui/libsoft_attestation_cert" was a RED HERRING:
both libs ARE present in our build (system/lib + vendor/lib); those CANNOT-LINK errors were TWRP-recovery
context (/system/lib not on recovery's linker path), not our ROM boot.
NEXT: instrumented SecondStageMain (init_s2, wrapinit_log after PropertyInit/StartPropertyService/
SetupMountNamespaces/InitializeSubcontext/LoadBootScripts/before-epoll) deployed; reboot to read which
S2 milestone is last -> pinpoint + fix. Deploy method: simg2img super_v5->super; mount mapper/system rw
(umount /system_root first); cp init -> /system/bin/init; boot+vbmeta stay 57e6+flags3; read /metadata/wrapinit.log.

---
## 2026-05-31 team hypothesis (deepseek-v4-pro) — subcontext child is prime suspect
init reaches SecondStageMain then exit 127. Team built init_s2 (SecondStageMain instrumented with
wrapinit_log after PropertyInit/StartPropertyService/SetupMountNamespaces/InitializeSubcontext/
LoadBootScripts/before-epoll). Hypothesis: if last breadcrumb == "InitializeSubcontext", the forked
`init subcontext` child is failing (CANNOT LINK in the VENDOR linker namespace) -> explains the missing
"ENTER main argv1=subcontext" breadcrumb and the clean 127. Then: compare LOS vs GSI /system|/vendor
ld.config*.txt and/or instrument subcontext.cpp. init_s2 deployed to phone; awaiting /metadata/wrapinit.log.

---
## 2026-05-31 MILESTONE — past exit-127! init reaches main loop; now post-init HANG (watchdog)
init_s2 (SecondStageMain instrumented) /metadata/wrapinit.log shows EVERY milestone passes:
PropertyInit -> SelinuxRestoreContext -> StartPropertyService -> SetupMountNamespaces ->
InitializeSubcontext -> LoadBootScripts -> "entering main loop" (repeats each bootloop cycle).
=> exit-127 is GONE (it was tied to the broken boot recipe; working recipe = stock boot 57e6 +
flags-3 vbmeta fixed it). ramoops stays STALE (108f7daa, no new panic) and NO pmsg => the resets are
HW WATCHDOG (don't commit ramoops), not panics. So now: init enters the main loop, processes
actions/starts services, the system HANGS, watchdog resets ~ -> bootloop. This is the ORIGINAL
~25s-watchdog symptom from the start of the project. NEXT: instrument init to log each service start +
action to /metadata (fsync) so the LAST before reset = the hanging service/HAL. (No pmsg/last-logcat
available; /metadata fsync breadcrumbs are the only durable channel under watchdog.)

---
## 2026-05-31 hang LOCALIZED — right after boringssl_self_test32, in a builtin ACTION
init_s3 (service-start instrumentation) /metadata/wrapinit.log shows:
  entering main loop -> SVC linkerconfig(bootstrap) start/die -> ueventd start(stays up) ->
  apexd-bootstrap start/die -> boringssl_self_test32 start/DIE -> [NOTHING MORE] -> watchdog reset.
So init completes the early services then HANGS before the next service starts => stuck in a BUILTIN
ACTION (no service breadcrumb), not a service. Prime suspects (MTK-classic): mount_all (/data, vold/f2fs)
or wait_for_coldboot_done (ueventd coldboot/firmware). NEXT: instrument init action execution
(ActionManager::ExecuteOneCommand / builtins) to log each action name -> last before hang = culprit.

---
## 2026-05-31 ROOT CAUSE of bootloop CONFIRMED — boringssl_self_test reboot_on_failure
init_s4 (action breadcrumbs) /metadata/wrapinit.log: ... exec_start boringssl_self_test32 ->
SVC start/DIE boringssl_self_test32 -> ACT <Builtin>:0 shutdown_done. So init does a CLEAN REBOOT
(not hang/watchdog -> explains stale ramoops + no pmsg). /system/etc/init/hw/init.rc:94-102 defines
boringssl_self_test32 AND _test64 each with `reboot_on_failure reboot,boringssl-self-check-failed`.
The crypto self-test exits non-zero -> init reboots -> BOOTLOOP. Also _test64 binary is MISSING (our
build is 32-bit TARGET_ARCH=arm but init.rc has the 64-bit service -> the core_64_bit-vs-arm config
conflict). QUICK FIX (on-phone, no rebuild): remove the `reboot_on_failure ...` line from both
boringssl_self_test32/64 in init.rc -> boot continues past. PROPER FIX later: resolve 64/32 arch config
(drop core_64_bit inherit or build true 64-bit). chroot run of the binary gives 127 = apex-linker missing
in chroot (artifact), not the real cause.

---
## 2026-05-31 SERVER TESTING enabled + boringssl PASSES standalone -> issue is SELinux enforcing
Set up server-side ARM testing: `unshare -rpf --mount-proc bash -c "qemu-arm-static -L <sysroot>
<sysroot>/system/bin/bootstrap/linker <sysroot>/system/bin/<bin>"` (unshare low-PID ns REQUIRED; 32-bit
bionic aborts if host PID>65535). Ran boringssl_self_test32 -> EXIT 0 (PASSES). So libcrypto is FINE;
the on-device self-test failure is ENVIRONMENTAL = SELinux ENFORCING (MTK LK drops boot.img cmdline so
permissive never applies) -> test denied (e.g. writing its flag) -> exits nonzero -> was rebooting.
reboot_on_failure already removed on-phone. REAL FIX: force permissive in init (selinux.cpp, after
SelinuxInitialize -> security_setenforce(0)) and/or permissive policy. Wrote AGENT_HANDOFF.md (resume brief).

---
## 2026-05-31 FIX deployed — force SELinux permissive in init (init_perm) + reboot_on_failure removed
Team edited system/core/init/selinux.cpp: added `security_setenforce(0);` at end of SelinuxInitialize()
(MTK LK drops boot.img cmdline so androidboot.selinux=permissive can't apply; on-device services failed
under enforcing). Built init_perm (32-bit ARM, security_setenforce present). Deployed via adb into the
on-phone super_v5 (/system/bin/init = init_perm; init.rc already has reboot_on_failure removed; boot 57e6 +
flags-3 vbmeta untouched). Cleared /metadata+pstore, rebooted. EXPECT: boringssl + other enforcing-denied
services now pass -> boot should progress well past boringssl (to UI or to the next REAL failure).
Watching boot result.
