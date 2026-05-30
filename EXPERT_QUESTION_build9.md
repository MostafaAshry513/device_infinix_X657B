# Expert question — Infinix X657B (MT6761, Android 11) LineageOS 18.1 custom ROM

## Device / setup
- Infinix Smart 5 **X657B**, MediaTek **MT6761** (Cortex-A53), Android 11, **32-bit userspace
  (Go edition)**, non-A/B, **dynamic partitions** (super), 3 GB RAM.
- Building **LineageOS 18.1** from source on the proven device tree
  (Miracleprjkt/Device_Infinix_X657B, branch LineageOS-18.1) + retargeted to LOS.
- **Stock kernel** (prebuilt, 4.19.127), **stock vendor** partition (treble), our built
  system/system_ext/product. vbmeta built with `--flags 3` (AVB fully disabled).

## Current symptom
First-stage init succeeds completely. Ramoops (kernel console):
```
init: init first stage started!
EXT4-fs (mmcblk0p7 /metadata): mounted    (e2fsck skipped: "executable not in system image")
EXT4-fs (dm-0 system): mounted
EXT4-fs (dm-1 system_ext): mounted
EXT4-fs (dm-2 vendor): mounted
EXT4-fs (dm-3 product): mounted
Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
```
=> PID 1 exits **127**, ~immediately after the last mount, **logging nothing** in second
stage (no "init second stage started", no "Loading SELinux policy").

## What we have ruled OUT
1. **Linking**: /system/bin/init is 32-bit ARM, interp /system/bin/bootstrap/linker; all
   NEEDED libs in /system/lib; bootstrap linker + bootstrap libs present. Running
   `chroot <system> /system/bin/init selinux_setup` ON THE DEVICE (TWRP) links fine and
   reaches "Loading SELinux policy" → so the binary links and runs.
2. **SELinux policy validity**: reproduced init's boot-time `secilc` compile on a host with
   the exact files (plat_sepolicy.cil + mapping/30.0.cil + system_ext_sepolicy.cil +
   mapping/30.0.cil + stock vendor vendor_sepolicy.cil + plat_pub_versioned.cil) →
   **exit 0, valid 935 KB policy**. Vendor `plat_sepolicy_vers.txt` = 30.0, system has
   mapping/30.0.cil. Versions match.
3. exit **127** (clean exit), not SIGABRT (6) → so it's NOT init's `LOG(FATAL)` paths
   (first_stage_mount fail / execv fail / "Unable to load SELinux policy" would be 6).

## Confirmed environment quirk
The MTK LK **ignores the boot.img command line**. Kernel actually receives (preloader/LK):
```
... bootopt=64S3,32S1,32S1 buildvariant=user root=/dev/ram androidboot.verifiedbootstate=orange ...
```
No `androidboot.selinux=permissive` (ours in boot.img is dropped) → boots **enforcing**.

## Questions
1. What makes second-stage `/system/bin/init` exit **127** (not 6) within milliseconds of
   switch_root, before emitting ANY second-stage log? (kernel selinux enforcing w/ no policy
   loaded denying the early second-stage exec/op? bootstrap dynamic-linker fallback failing
   only in the real early-boot mount namespace, vs. a chroot? something in
   SetStdioToDevNull / InitKernelLogging before SelinuxInitialize?)
2. Given the LK drops our cmdline, what's the reliable way to boot **permissive** on this MTK
   device without touching LK/preloader? (bake permissive into the compiled policy? patch
   init's default enforce mode? a matching precompiled_sepolicy in vendor?)
3. With stock vendor + custom LOS system on MT6761, is shipping a **matching
   precompiled_sepolicy** in vendor (so init skips boot-time compile) the right call, and is
   the boot-time compile path (needs /sys/fs/selinux/null, file_contexts) a likely culprit?

## Data available on request
Full ramoops, FINDINGS_build9_exit127.md, BUILD_FIXES.md (GitHub MostafaAshry513/device_infinix_X657B
+ Mega /X657B-build/roms/build-9-los-boot/).
