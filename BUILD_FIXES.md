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

---
## 2026-05-31 PROGRESS — permissive cleared system boringssl; now VENDOR boringssl reboots
init_perm (permissive) /metadata/wrapinit.log: boot now passes system boringssl_self_test32 (no reboot,
reboot_on_failure removed) AND runs ALL vendor init (init.modem.rc, init.mt6761.rc, init.project.rc,
modprobe vendor .ko) -> then dies at /vendor/etc/init/boringssl_self_test.rc:3 exec_start
boringssl_self_test32_vendor -> SVC died -> shutdown_done (vendor boringssl still has reboot_on_failure).
So it's whack-a-mole on reboot_on_failure boringssl services. FIX: strip reboot_on_failure from ALL init
rc (system + vendor), incl /vendor/etc/init/boringssl_self_test.rc. (init_perm carries all our breadcrumbs
+ security_setenforce(0); boot/vbmeta 57e6+flags3; super=super_v5 on phone.)

---
## 2026-05-31 removed reboot_on_failure from system bpfloader.rc + apexd.rc (vendor had none)
Team grep: reboot_on_failure was in /system/etc/init/bpfloader.rc and apexd.rc (apexd-bootstrap:
reboot,bootloader,bootstrap-apexd-failed). Vendor rc = 0. Removed all 3 lines. So the shutdown_done that
appeared right after boringssl_self_test32_vendor was likely apexd/bpfloader failing (reboot_on_failure),
not the vendor boringssl per se. Rebooted to test. NOTE: if apexd-bootstrap is genuinely failing, boot
continues now but APEXes may be unmounted -> later breakage; watch next breadcrumbs.

---
## 2026-05-31 HUGE PROGRESS — boot reaches zygote/surfaceflinger; core services crash-LOOP -> fastboot
With permissive + all reboot_on_failure removed, boot goes deep (1922 breadcrumbs): past boringssl,
mount_all/vold, vendor HALs, logd, servicemanager, hwservicemanager, zygote, surfaceflinger, keystore,
Magisk (/debug_ramdisk/magisk --zygote-restart). But core services crash-LOOP: logd x5, servicemanager x5,
hwservicemanager x4, vold x4, zygote x4, surfaceflinger x4. First deaths: logd(292) -> servicemanager(301)
-> zygote(323) -> cascade (onrestart/class_restart). adbd NEVER starts (no live logcat). No tombstones
(/data wiped), no pmsg (logd dies), ramoops stale (no panic; bootloader fail-counter -> fastboot).
SERVER TEST (qemu): servicemanager LINKS fine (only fails on missing /dev/binder, which exists on device)
=> NOT a lib/link issue; it's a RUNTIME crash. NEXT: instrument Service::Reap to log exit status/signal in
the "SVC died" breadcrumb -> first service with SIGSEGV/SIGABRT = the true root. Suspects: VINTF mismatch
(our system vs stock vendor) cascading via hwservicemanager; Magisk interference; 64/32 (core_64_bit) config.

---
## 2026-05-31 ROOT of crash-loop FOUND — every service exits 127 (apex linker missing)
init_s5 death-reason breadcrumbs: EVERY service dies code=1 status=127 (logd, servicemanager, vold, zygote,
keymaster, ALL of them). code=1=CLD_EXITED, status=127 => the service process exits 127 = dynamic loader
cannot exec/link it. Services use interp /system/bin/linker -> /apex/com.android.runtime/bin/linker (the
APEX linker). apexd-bootstrap exited code=1 status=0 (SUCCESS) yet /apex/com.android.runtime is NOT usable.
/system/apex is INCONSISTENT: contains BOTH flattened apex DIRS (com.android.runtime, com.android.art.release,
com.android.adbd, conscrypt, media, media.swcodec) AND .apex FILES for the same names. So the runtime apex
isn't activated -> apex linker missing -> all services exit 127 -> crash-loop -> fastboot.
ROOT = apex flattening/build-config inconsistency (likely tied to core_64_bit-vs-arm / mixed flatten config).
FIX directions: (a) build consistently (TARGET_FLATTEN_APEX or proper updatable apex) + rebuild; (b) ensure
apexd activates com.android.runtime; (c) workaround: point /system/bin/linker at /system/bin/bootstrap/linker.
Handed to the team to fix. init itself runs (bootstrap linker); only services (apex linker) fail.

---
## 2026-05-31 FIXED — exit-127 ROOT CAUSE: core_64_bit.mk caused hybrid APEX (dirs+.apex files)
### DIAGNOSIS
The device tree had three conflicting APEX configs:
1. BoardConfig.mk: `OVERRIDE_TARGET_FLATTEN_APEX := true` (flatten APEXes into dirs)
2. device.mk: `$(call inherit-product, updatable_apex.mk)` (produce updatable .apex files)
3. lineage_X657B.mk: `$(call inherit-product, core_64_bit.mk)` (64-bit support, but BoardConfig
   says TARGET_ARCH=arm, TARGET_CPU_ABI=armeabi-v7a — 32-bit only)

The `updatable_apex.mk` is guarded by `ifneq ($(OVERRIDE_TARGET_FLATTEN_APEX),true)` so it's a
no-op when OVERRIDE is true. The REAL culprit was `core_64_bit.mk`: it caused the build system to
produce BOTH 32-bit flattened APEX dirs AND 64-bit .apex files for every APEX module (com.android.runtime,
com.android.art.release, com.android.adbd, conscrypt, media, media.swcodec — ALL of them had both
a directory and a .apex file with the same name). The resulting `/system/apex/` hybrid layout meant
the runtime APEX was never properly flattened → `/apex/com.android.runtime/bin/linker` was not
resolvable → every service (which uses interp `/system/bin/linker` → `/apex/com.android.runtime/bin/linker`)
exited 127 (dynamic linker not found).

### FIX
Two changes to `/root/android/lineage/device/infinix/X657B/`:

1. **lineage_X657B.mk** — removed `$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)`.
   This device is 32-bit ARM only (TARGET_ARCH=arm, TARGET_CPU_ABI=armeabi-v7a, 32-bit zygote in vendor
   init.zygote32.rc). Including core_64_bit.mk caused APEX ABI confusion → hybrid dir+file layout.

2. **device.mk** — kept `updatable_apex.mk` (needed for APEX module inclusion in system.img; its
   `TARGET_FLATTEN_APEX := false` is blocked by OVERRIDE_TARGET_FLATTEN_APEX=true guard, so it's harmless).
   Verified: BoardConfig.mk's `OVERRIDE_TARGET_FLATTEN_APEX := true` remains (forces flattened APEX dirs,
   no .apex files).

Also confirmed: the 64-bit zygote init.zygote64_32.rc was removed from the build output, and the
CTS shim .apk (which was inside com.android.apex.cts.shim.apex) was moved to standalone APKs.

### RESULT (verified in system.img)
- OLD /system/apex/: **21 .apex files + mixed dirs** (hybrid — BROKEN)
- NEW /system/apex/: **21 directories, ONLY 1 .apex file** (com.android.apex.cts.shim.apex — harmless CTS shim)
- /system/apex/com.android.runtime/ has bin/linker + lib/ → fully flattened, linker resolved
- /system/bin/linker → /apex/com.android.runtime/bin/linker (correct symlink)
- /system/apex/com.android.runtime/bin/linker: ELF 32-bit ARM static-pie (real linker, not missing)
- build log confirms: `Removed: init.zygote64_32.rc` (64-bit zygote gone)

### SERVER QEMU VALIDATION
```
unshare -rpf --mount-proc bash -c "qemu-arm-static -L /tmp/qemu_sys \
  /tmp/qemu_sys/system/bin/bootstrap/linker /tmp/qemu_sys/system/bin/servicemanager"
→ linker loads, servicemanager executes (dies on missing /dev/binder — expected in chroot)
→ NO exit 127, NO linker error
```
surfaceflinger: CANNOT LINK "libstatssocket.so" — APEX-path issue in chroot only (on-device apexd
sets up linker namespaces; lib IS present at /system/apex/com.android.os.statsd/lib/)
zygote: CANNOT LINK "libnativeloader.so" — same chroot artifact.

### DEPLOYMENT (build-10 / super_v6)
- Built system.img with fix (720M sparse). Assembled super_v6 (1.5G sparse) with:
  system (new, 968M raw) + vendor_fixed (stock noophyy, 320M raw) + product (250M sparse) + system_ext (202M sparse).
- Pushed system_v6.img only (720MB, 130s over SSH tunnel), dd'd to /dev/block/by-name/system.
- Boot partition: working_ref stock boot 57e6f9def... (already on phone, verified md5).
- Vbmeta: flags-3 (AVB disabled, already on phone from flash_build9).
- Formatted /data + /metadata, cleared pstore. Rebooted.
- Device NOT back on adb after ~5min → either booting Android (success!) or in bootloop needing
  manual TWRP key-combo recovery.
- Files: /root/android/flash_build9/system_v6.img (on phone as /sdcard/system_v6.img),
  super_v6.img (1.5G, /root/android/flash_build9/super_v6.img).
- NEXT: user must check phone screen — if boot animation showing = SUCCESS (wait for adb),
  if logo→reboot→recovery = need ramoops/wrapinit.log diagnosis.

---
## build-11: linker fix for ALL services exiting 127 + boringssl reboot_on_failure removal  [NOT YET FLASHED]
### CONTEXT
build-10 (core_64_bit fix, clean APEX layout) booted DEEP past all prior blockers: init reaches
all triggers (fs, post-fs, post-fs-data, zygote-start, early-boot, boot), executes 1295+ actions,
starts ALL services. But EVERY dynamically linked service crashes `code=1 status=127`:
`logd`, `servicemanager`, `zygote`, `surfaceflinger`, `vold`, ALL HALs, etc.
Status 127 = dynamic linker cannot exec.

### ROOT CAUSE — /system/bin/linker symlink chain fails during early boot
`/system/bin/linker` → `/apex/com.android.runtime/bin/linker` → `/system/apex/com.android.runtime/bin/linker`
This double-symlink traversal through the APEX namespace fails during early boot (apexd-bootstrap hasn't
fully activated the APEX linker namespace yet). The static first-stage init works fine, but ALL
second-stage dynamically linked services fail.

### BUILD-11 FIXES (3 separate fixes, cumulative)

#### Fix 1: Formatted md_udc (mmcblk0p7) as ext4
- Problem: First-stage init failed to mount /metadata → `mount(/dev/block/.../md_udc,/metadata,ext4)=-1: No such file or directory`
- Root cause: md_udc partition (mmcblk0p7) was blank/corrupted. Previously we formatted metadata (mmcblk0p6) — DIFFERENT partition.
- Fix: `mke2fs -t ext4 /dev/block/by-name/md_udc` on phone
- Result: First-stage init mounts /metadata successfully, first-stage completes cleanly

#### Fix 2: Commented out `reboot_on_failure` from boringssl_self_test services in init.rc
- Problem: `boringssl_self_test32` exits non-zero → `reboot_on_failure` triggers → `shutdown_done` → reboot → bootloop
- Fix: Commented out `reboot_on_failure` from all 4 boringssl services in `/system/etc/init/hw/init.rc`:
  - boringssl_self_test32 (line 96)
  - boringssl_self_test64 (line 101)
  - boringssl_self_test_apex32 (line 106)
  - boringssl_self_test_apex64 (line 111)
- Note: bpfloader.rc and apexd.rc `reboot_on_failure` were already removed on-phone in prior iteration
- Status: DEPLOYED AND VERIFIED — boot continues past boringssl, reaches all services

#### Fix 3: Replaced /system/bin/linker symlink with real binary
- Problem: `/system/bin/linker` is a symlink → `/apex/com.android.runtime/bin/linker` which
  is itself a symlink → `/system/apex/com.android.runtime/bin/linker`. This chain fails
  during early boot before apexd fully activates the APEX linker namespace.
- Fix: Replaced the symlink with the REAL linker binary copied from
  `/system/apex/com.android.runtime/bin/linker` (ELF 32-bit ARM static-pie, 1,063,260 bytes)
- BuildID: 985587a4d0a3f64144c86bc954bcecda
- This should fix ALL services exiting 127 since every dynamically linked service uses this linker

### sys_patch.raw — COMBINED PATCH IMAGE (server, NOT YET FLASHED)
- **File:** `/tmp/sys_patch.raw` on server
- **MD5:** `0b6d751914bf526ff12ed71c1e34ffc7`
- **Size:** 924MB (raw ext2 filesystem, NOT sparse)
- **Contents:** Full system partition with Fix 2 (boringssl reboot_on_failure removal) + Fix 3 (linker binary replacement)
- **Based on:** build-10 system.img (core_64_bit fix, clean APEX: 21 dirs + 1 .apex file)
- **Verified:** 
  - `/system/bin/linker`: ELF 32-bit ARM static-pie, 1,063,260 bytes (real binary, NOT symlink)
  - init.rc: All 4 boringssl `reboot_on_failure` lines commented out
  - bpfloader.rc: `reboot_on_failure` active (not yet tripped in boot flow; on-phone fix from prior iteration)
  - apexd.rc: `reboot_on_failure` active (same — not yet tripped)

### PHONE CURRENT STATE (as of 2026-05-31)
- Boot: stock boot md5 57e6f9def... (from /root/android/working_ref/boot.emmc.win)
- Vbmeta: flags-3 (AVB disabled)
- System: build-10 + on-phone boringssl reboot_on_failure removal (OLD sys_patch.raw md5 e477b269)
  - Has boringssl fix but NOT linker fix
  - Boot goes deep (1295 init actions) but ALL services exit 127
- Recovery: TWRP accessible via ADB over SSH tunnel
- md_udc (/metadata): Formatted ext4, working

### NEXT STEP
**Transfer sys_patch.raw (MD5 0b6d7519) from server to MacBook, then flash via fastbootd.**
This single step deploys the linker fix that should resolve the 127 failures for ALL services.
Transfer: `ssh -p 2222 brucewayne@localhost 'cat > /tmp/sys_patch.raw' < /tmp/sys_patch.raw` (924MB, ~5min over tunnel)
Flash: `fastboot reboot fastboot` then `fastboot flash system /tmp/sys_patch.raw`
Test: `fastboot reboot` then poll ADB

### BUILD-11 ARTIFACTS
- `/tmp/sys_patch.raw` (server): MD5 0b6d751914bf526ff12ed71c1e34ffc7, 924MB — linker fix + boringssl fix
- `/tmp/sys_patch.raw` (MacBook): MD5 e477b26900c854d5fb5d899538620e9f — boringssl fix ONLY (old, already flashed)
- Mega: `/X657B-build/roms/build-11/sys_patch.raw` ✅ uploaded
- Mega: `/X657B-build/roms/build-11/debug_artifacts.tar.gz` (5.2MB) — 15 ramoops logs, 9 init variants, wrapinit_deep.log, team notes
- Mega: `/X657B-build/roms/build-10/super_v6.img` (1.5G) — full super with core_64_bit fix
- Mega: `/X657B-build/roms/build-10/system.img` (720M) — build-10 source system
- Mega: `/X657B-build/session_log.md` ✅ updated — full session state
- GitHub: `BUILD_FIXES.md` ✅ synced (commit `0f96643`)

### ALL MEGA ARTIFACTS (2026-05-31)
```
/X657B-build/
├── session_log.md              ← updated with full build-1 through build-11 timeline
├── BUILDS.md
├── roms/
│   ├── build-4/
│   ├── build-7-source/
│   ├── build-8-proven-tree/
│   ├── build-9-los-boot/
│   ├── build-10/
│   │   ├── super_v6.img        (1.5G) — build-10 full super
│   │   └── system.img          (720M) — build-10 source system
│   └── build-11/
│       ├── sys_patch.raw       (924M) — MD5 0b6d7519, linker+boringssl fixes
│       └── debug_artifacts.tar.gz (5.2M) — ramoops, init variants, wrapinit log
├── archive/
└── backups/
```

---
## 2026-05-31 ROOT CAUSE of the 127s NAILED: ro.apex.updatable=true vs FLATTENED apex
### EVIDENCE (on-phone, build-10 system, via adb in TWRP)
- /system/apex = 20 flattened DIRS + 1 harmless shim .apex (clean, build-10 fix intact).
- /system/bin/linker = proper symlink -> /apex/com.android.runtime/bin/linker (band-aid did NOT leak).
- wrapinit.log: `SVC start: apexd-bootstrap` then `SVC died: apexd-bootstrap code=1 status=0`
  (apexd --bootstrap EXITS 0 / "success") — yet EVERY later dynamically-linked binary 127s
  (tune2fs, teei_daemon, vdc...). So apexd ran but populated NOTHING into /apex.
- /system/build.prop: **ro.apex.updatable=true**  ← THE BUG.

### WHY
Apexes are FLATTENED (dirs), but ro.apex.updatable=true puts apexd in UPDATABLE mode: it looks for
.apex images to verify+loop-mount, finds none, bind-mounts nothing, exits 0 → /apex stays empty →
/apex/com.android.runtime/bin/linker missing → every service/exec exits 127.
For flattened apex, ro.apex.updatable MUST be false (then apexd bind-mounts /system/apex/* -> /apex/*).
Leaked in from updatable_apex.mk (sets ro.apex.updatable=true); build-10 wrongly assumed it harmless.

### QUICK ON-PHONE TEST (no rebuild)
Flipped /system/build.prop ro.apex.updatable=true->false, cleared wrapinit.log+pstore, rebooted to system.
Watching: boot_completed=1 => SUCCESS; back to recovery => read fresh wrapinit. (result pending)

### PROPER FIX (team build-12, in progress)
Bake ro.apex.updatable=false for this flattened-apex device (drop updatable_apex.mk's prop, or force
PRODUCT_PROPERTY_OVERRIDES ro.apex.updatable=false), rebuild systemimage.

---
## 2026-05-31 PIVOTAL: real-linker diagnostic localizes root cause to APEX LIB NAMESPACE (not symlink)
### TEST (on-phone, no rebuild)
1. Flipped ro.apex.updatable true->false, rebooted -> STILL all services status=127. So that prop is NOT the lever.
2. Replaced /system/bin/linker symlink with the REAL linker binary (copied from
   /system/apex/com.android.runtime/bin/linker), rebooted.
### RESULT (decisive)
Failure mode CHANGED: 127 -> status=1 (and some status=11 SIGSEGV) for EVERY service
(logd, servicemanager, hwservicemanager, zygote, surfaceflinger, installd, ...).
- 127 = linker not found  ->  status=1 = linker RAN but cannot link the shared libs.
### MEANING
The linker symlink resolution was a real (secondary) issue, but the PRIMARY blocker is that /apex is
never populated -> apex libs (/apex/*/lib) + linkerconfig namespace are missing -> linker loads but every
service fails to resolve its libraries. apexd-bootstrap exits 0 yet bind-mounts NOTHING into /apex.
The build-11 "real linker" band-aid therefore CANNOT boot (proven, not guessed).
### PROPER FIX (team, build-12) — pick the robust path:
(A) Drop the OVERRIDE_TARGET_FLATTEN_APEX hack entirely -> build STANDARD updatable apex (real .apex files
    loop-mounted by apexd; the proven LineageOS 18.1 path). OR
(B) Fix flattened-apex activation: ensure /apex tmpfs + apexd bind-mounts propagate into the service mount
    namespace + no selinux block. (flattened apex is deprecated/finicky -> prefer A.)
bootwatch.sh now auto-recovers phone fastboot->TWRP on bootloop.

---
## 2026-05-31 DECISION: abandon flattened apex -> STANDARD UPDATABLE apex (build-12)
### Why flattened was a dead end
- /apex never populated in EITHER mode. Flattened: apexd-bootstrap exits 0 but bind-mounts nothing
  (apex CONTENTS verified present on disk: com.android.runtime/lib has bionic libc/libdl/libm, ld-android,
  libc++, apex_manifest.pb). Flipping ro.apex.updatable false made NO difference.
- BoardConfig.mk had forced OVERRIDE_TARGET_FLATTEN_APEX=true with the justification "stock kernel lacks
  loop-device support for updatable apex." **That justification is FALSE.**
### Kernel proof (extract-ikconfig on working_ref/boot.emmc.win = the Android boot kernel)
  CONFIG_BLK_DEV_LOOP=y ; CONFIG_BLK_DEV_LOOP_MIN_COUNT=16
  CONFIG_BLK_DEV_DM=y ; CONFIG_DM_VERITY=y ; CONFIG_DM_VERITY_AVB=y ; CONFIG_DM_VERITY_FEC=y
  (phone also shows /dev/block/loop0..15). So the kernel FULLY supports updatable apex (loop + dm-verity).
### Fix applied
- Removed `OVERRIDE_TARGET_FLATTEN_APEX := true` from device/infinix/X657B/BoardConfig.mk.
  Now builds standard updatable apex (real .apex files, apexd loop-mounts + per-apex dm-verity).
  This is the proven LineageOS 18.1 default path and is internally CONSISTENT with ro.apex.updatable=true.
- Team building build-12 (mka systemimage) -> system_v12.img. Will verify /system/apex has *.apex files.
### Next: deploy system_v12 to phone (adb dd to /dev/block/by-name/system), keep boot 57e6 + vbmeta flags-3,
  reboot, read wrapinit.log -> expect apexd to loop-mount /apex/com.android.runtime -> services link -> boot.

---
## 2026-05-31 ===== CONSOLIDATED DISCOVERY SUMMARY (session) =====
THE BUG (root cause of the universal service crash-loop -> fastboot):
  /apex is NEVER populated at runtime -> /apex/com.android.runtime/bin/linker + all apex libs missing
  -> every dynamically-linked service/exec fails. apexd-bootstrap exits 0 but activates NOTHING.

HOW WE PROVED IT (on-phone, build-10 system, adb-over-Mac-tunnel; NO rebuilds needed):
  1. /system/apex = 20 flattened DIRS + 1 shim (clean since build-10); contents OK
     (com.android.runtime/lib has bionic libc/libdl/libm, ld-android, libc++, apex_manifest.pb).
  2. wrapinit.log: `apexd-bootstrap ... code=1 status=0` (exits success) yet every later binary 127.
  3. Test A: flip ro.apex.updatable true->false, reboot -> STILL all 127. (prop alone is NOT the fix)
  4. Test B: replace /system/bin/linker symlink with REAL linker binary, reboot
     -> failure mode CHANGED 127 -> status=1 (+some SIGSEGV/11). Linker now RUNS but cannot link libs.
     => root cause localized to APEX LIB NAMESPACE (/apex empty), not the symlink. Band-aid can't boot.
  5. init.rc has NO `mount tmpfs tmpfs /apex` line (relies on C++ init/apexd to create+propagate /apex).

WHY FLATTENED WAS A DEAD END (and the buried mistake):
  BoardConfig.mk forced OVERRIDE_TARGET_FLATTEN_APEX=true with comment "stock kernel lacks loop-device
  support for updatable apex." THAT IS FALSE. extract-ikconfig on working_ref/boot.emmc.win (the Android
  boot kernel) shows: CONFIG_BLK_DEV_LOOP=y, LOOP_MIN_COUNT=16, BLK_DEV_DM=y, DM_VERITY=y, DM_VERITY_AVB=y.
  Phone shows /dev/block/loop0..15. So updatable apex IS supported. Forcing flatten created an inconsistent
  config (flattened dirs + ro.apex.updatable=true) that apexd could never activate; flattened failed the
  SAME way as updatable -> the loop-device theory mis-sent prior work into the flatten dead-end.

THE FIX (build-12, compiling now):
  Removed `OVERRIDE_TARGET_FLATTEN_APEX := true` from device/infinix/X657B/BoardConfig.mk -> standard
  UPDATABLE apex (real .apex files, apexd loop-mounts + per-apex dm-verity; the proven LOS 18.1 default,
  consistent with ro.apex.updatable=true). Building system_v12.img via `mka systemimage`.

DEPLOY PLAN: adb dd system_v12 -> /dev/block/by-name/system; keep boot 57e6 + vbmeta flags-3; clear
  /metadata + pstore; reboot; read wrapinit.log. Expect apexd to loop-mount /apex/com.android.runtime
  -> services link -> boot proceeds. bootwatch auto-recovers fastboot->TWRP on bootloop.

INFRA NOTES: adb/fastboot reach the phone via the Mac over reverse tunnel (server:2222 -> Mac:22, user
  brucewayne, /usr/local/bin/adb|fastboot). Server wrappers: ~/bin/padb, ~/bin/bootwatch.
  Headless qwen team flaked once (13 min, zero output) -> for critical surgical edits do them directly;
  delegate the heavy compile to the team.

---
## 2026-05-31 build-12 BUILT + verified (updatable apex). Deploying via shrink-to-fit.
### BUILD RESULT (mka systemimage, OVERRIDE_TARGET_FLATTEN_APEX removed)
- out/.../system.img sparse 762M, raw 979M, md5 0c8c754826b90aaaf006e60be01c67da
- /system/apex now = **21 real *.apex FILES** (com.android.runtime.apex, com.android.art.release.apex,
  com.android.conscrypt.apex, com.android.i18n.apex, com.android.tzdata.apex, ...) — UPDATABLE, not flattened.
- ro.apex.updatable=true (consistent now); /system/bin/apexd present; /system/bin/linker -> apex symlink.
- (team agent died mid-verify on agentrouter QUOTA error: $0.055 left < $0.0592 needed — credits ~exhausted.
   Build itself completed; orchestrator did verification.)
### DEPLOY (no super rebuild needed; kind to limited internet)
- system_v12 content only 712MB used inside 979MB fs; existing logical system partition = 968,802,304 B (924MiB).
- e2fsck + resize2fs shrunk fs to 920MiB (964,689,920 B) -> FITS partition. img2simg -> system_v12_fit.img
  (708MB sparse, md5 1ec0834cb6b5f754825df906d573a8fe), saved /root/android/flash_build9/system_v12_fit.img.
- Path: scp server->Mac:/tmp (708MB over tunnel) -> adb push -> phone /sdcard -> simg2img to
  /dev/block/mapper/system -> e2fsck -> clear /metadata+pstore -> reboot. boot 57e6 + vbmeta flags-3 unchanged.
- EXPECT: apexd loop-mounts /apex/com.android.runtime (kernel has loop+dm-verity) -> services link -> boot.

---
## 2026-05-31 ===== REAL ROOT CAUSE: SELinux ENFORCING (permissive-force never worked) =====
Full writeup: FINDINGS_apex_selinux.md (GitHub + Mega).
- On-device: /sys/fs/selinux/enforce = 1 (ENFORCING) at runtime, captured via init.rc builtin
  `copy /sys/fs/selinux/enforce /metadata/dbg_enforce.txt` after apexd-bootstrap.
- Under enforcing, apexd's mounts are DENIED -> apexd-bootstrap exits 0 but /apex never populated ->
  /apex/com.android.runtime/bin/linker missing -> every service exits 127. (Same in flattened AND updatable
  apex -> apex-mode was never the cause.) build-12 updatable apex was verified correct but irrelevant to the wall.
- WHY permissive-force fails: selinux.cpp SelinuxInitialize() sets enforce=1 (line 480, is_enforcing=true
  because StatusFromCmdline defaults ENFORCING and MTK strips cmdline), THEN our security_setenforce(0)
  (line 492) is silently DENIED once enforcing (return unchecked). Net = enforcing.
- FIX TO TRY FIRST: selinux.cpp:95 default SELINUX_ENFORCING -> SELINUX_PERMISSIVE so IsEnforcing()=false
  -> never flips enforcing -> setenforce(0) sticks. Cheap test: `mka init`, deploy ONLY the ~2MB init binary,
  reboot, check enforce=0 + /apex populates.
- OPEN: why apexd denied under enforcing on this build (likely LOS-system + STOCK-vendor sepolicy mismatch);
  capture real AVC denials next session. SECONDARY: bake boringssl reboot_on_failure removal into SOURCE.
- STATUS: user asleep; no further device actions. glm-5.1 researching -> flash_build9/glm_research.txt.

---
## 2026-05-31 ===== DECISIVE: KERNEL IS ENFORCE-LOCKED (CONFIG_SECURITY_SELINUX_DEVELOP not set) =====
Boot kernel (working_ref/boot.emmc.win) has DEVELOP/BOOTPARAM/DISABLE all NOT set -> SELinux is ALWAYS
ENFORCING; security_setenforce(0) is a no-op/denied. EVERY permissive-force this project tried was silently
ineffective -> we were always enforcing -> apexd mounts DENIED -> /apex empty -> all services 127.
Forcing IsEnforcing()->false made init's setenforce(0) FAIL -> init aborted in SelinuxInitialize -> kernel
panic "Attempted to kill init". Reverting that.
PATHS FORWARD: (A proper) fix the ENFORCING policy (GSIs boot enforcing here, so a correct policy works; ours
is broken from LOS-system + STOCK-vendor mismatch) -> capture AVC denials from ramoops, add allow rules /
use matched noophyy vendor. (B hack) ship a fully-permissive policy (magiskpolicy "permissive *" / typepermissive
all domains in CILs; works on locked kernels). NEXT: revert to enforcing instrumented init, boot to service
phase, capture avc denials. Full writeup FINDINGS_apex_selinux.md.

---
## 2026-05-31 (session 2) — capturing the apexd AVC denial (enforce-locked kernel) — IN PROGRESS
STATE OF PLAY:
- Kernel is ENFORCE-LOCKED (CONFIG_SECURITY_SELINUX_DEVELOP/BOOTPARAM/DISABLE all unset). Confirmed AGAIN:
  forcing permissive in init -> init aborts in SelinuxInitialize -> "Attempted to kill init" panic. So we
  MUST make the loaded policy work (or be permissive in-policy). Reverted selinux.cpp to enforcing.
- sepolicy sha MISMATCH confirmed on device: system plat_sepolicy sha (be5fd78a...) != vendor recorded
  (05bf9d9f...). => init does NOT use vendor precompiled_sepolicy; it COMPILES the policy on-device from LOS
  plat + STOCK vendor CILs (the same path GSIs use; GSIs boot enforcing here, so a correct policy works).
- With the rebuilt ENFORCING instrumented init (init_enforcing_v14, md5 6503117d, deployed): init reaches
  the SERVICE phase (wrapinit ~1925 lines) and EVERY service exits 127 (logd, servicemanager, keymaster,
  zygote, vendor HALs...). apexd-bootstrap exits code=1 status=0 but /apex is never populated -> 127.
  enforce dump = 1 (enforcing).
DIAGNOSTIC DIFFICULTY (no userspace logging since services 127):
- ramoops console-ramoops-0 only retains the LAST crash-loop iteration; the apexd iteration gets overwritten
  by later iterations. Also an intermittent FIRST-STAGE panic recurs: first-stage init sometimes can't mount
  /metadata (md_udc): "Filesystem on md_udc was not cleanly shutdown" + "Not running e2fsck (executable not in
  system image)" -> mount(md_udc,/metadata,ext4)=-1 -> panic exitcode=0x00007f00. (md_udc goes dirty from the
  repeated hard reboots and the ramdisk has no e2fsck to clean it. Intermittent; some boots mount fine.)
- Tried init.rc `copy /proc/kmsg /metadata/kmsg_at_apexd.txt` to capture the kernel log at the apexd point:
  MISTAKE — /proc/kmsg is a blocking stream, so init HUNG at the logo there (no file written). (That hang
  did at least pause the loop at the apexd phase.)
RELIABLE FIX IN PROGRESS: add a non-blocking kernel-ring dump to init via klogctl(SYSLOG_ACTION_READ_ALL)
-> write /metadata/klog_apexd.txt, triggered right after apexd-bootstrap (via a unique init.rc marker
"write /dev/kmsg DUMPKLOG_NOW" detected in action.cpp), then `setprop sys.powerctl reboot,recovery` for a
clean reboot to TWRP. Editing system/core/init/main.cpp (add wrapinit_dump_klog) + action.cpp (trigger).
PHONE NOW: in TWRP. /system has init_enforcing_v14 + an init.rc with the BAD blocking `copy /proc/kmsg` line
(needs replacing with the marker). boot=57e6, vbmeta flags-3. system_v12_fit.img is the deployed system.
NEXT: finish init klog-dump build, deploy init + fixed init.rc, boot, read /metadata/klog_apexd.txt for the
apexd "avc: denied ..." -> add allow rule(s) to device sepolicy (or switch to matched noophyy vendor) ->
rebuild -> enforcing boot. Fallback: fully-permissive in-policy (typepermissive all domains / magiskpolicy).

---
## 2026-05-31 (session 2) ===== TRUE ROOT CAUSE CONFIRMED: apex-mode mismatch w/ stock vendor =====
CAPTURED via new non-blocking klog dump (init klogctl READ_ALL -> /metadata/klog_apexd.txt). The log shows:
  apexd: "This device does not support updatable APEX. Exiting"
  init:  "/system/apex/com.android.runtime is not an APEX directory: Failed to read manifest file ..."
ro.apex.updatable: VENDOR build.prop line 420 = FALSE ; SYSTEM build.prop line 194 = TRUE. ro.* props are
FIRST-SET-WINS and the stock vendor's FALSE wins -> apexd runs in FLATTENED mode and EXITS (expects init to
bind-mount flattened apex DIRECTORIES). But build-12 shipped UPDATABLE .apex FILES -> init's flattened scan
fails -> /apex never populated -> /apex/com.android.runtime/bin/linker missing -> every service 127.
=> The stock Infinix VENDOR MANDATES FLATTENED APEX. build-12 (updatable) was the wrong call. The original
tree's OVERRIDE_TARGET_FLATTEN_APEX=true was CORRECT for this vendor. (Only avc denials in the log are
trivial: tranfs relabelto, our wrapinit.log append by vendor_init — NOT apexd.)

PLAN (logged BEFORE doing, per user request) — build-13 flattened, vendor-matched:
 1. Re-add `OVERRIDE_TARGET_FLATTEN_APEX := true` to device/infinix/X657B/BoardConfig.mk (revert build-12
    removal; keep core_64_bit.mk removed so no hybrid).
 2. mka systemimage (flattened rebuild).
 3. Verify /system/apex = flattened DIRS + apex_manifest.pb (NOT .apex files).
 4. Shrink-to-fit (resize2fs) + deploy system to phone (replace system partition; boot 57e6 + vbmeta flags-3).
 5. Boot: if boots -> DONE. If crash-loops -> deploy DUMPKLOG init.rc to capture init's flattened bind-mount
    step (this is where build-10, also flattened, mysteriously failed before we had the klog tool).
Note: deployed init has the klog-capture code (harmless without the marker). The build's init.rc restores
boringssl reboot_on_failure, but if /apex works boringssl self-test PASSES (no loop).

## 2026-05-31 build-13 note: flatten flag didn't invalidate cache -> forcing clean re-stage
`mka systemimage` after re-adding OVERRIDE_TARGET_FLATTEN_APEX said "ninja: no work to do"; out tree was
STALE+HYBRID (21 .apex files + 7 leftover dirs, system.img mtime old 13:18). PLAN (before doing): run
`make installclean` (clears staged PRODUCT_OUT incl /system/apex, keeps soong intermediates) then
`mka systemimage`; verify /system/apex = flattened DIRS only (no .apex). Then shrink-to-fit + deploy.
