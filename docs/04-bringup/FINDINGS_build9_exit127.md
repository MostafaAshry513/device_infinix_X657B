# BUILD-9 FINDINGS — Infinix X657B LineageOS 18.1 (2026-05-30)

## TL;DR
Boot progressed further than ever. **First-stage init now fully succeeds** (all 4 logical
partitions + /metadata mount). **Second-stage init dies instantly: `exitcode=0x00007f00`
(exit 127), logging NOTHING** — it dies at the very entry of second stage, *before* SELinux
policy load. Root cause of the 127 not yet pinned; sepolicy is proven to compile fine.

## Two real bugs fixed this session
1. **On-phone `system` partition was corrupt/truncated** (missing `/system/bin/init`,
   `build.prop`, `lib`, `framework`). A prior `simg2img`-to-block-device flash had left
   stale data in the partition gaps. Rewrote it with a complete, fsck-clean system.
   - LESSON: in TWRP, **`/system_root` must be unmounted first**, and writing a logical
     partition via `simg2img` to the dm device leaves gaps → corruption. Write the FULLY
     EXPANDED raw with `dd ... conv=notrunc`, or to the dm device after unmounting it.
2. **fstab `check` on first-stage mounts** removed (/metadata,/tranfs) — confirmed working
   (ramoops shows "Not running e2fsck ... (executable not in system image)" then clean mount).

## Ramoops timeline (real boot)
```
1.247  init: init first stage started!
1.248  init: [libfs_mgr]ReadFstabFromDt(): failed to read fstab from dt   (falls back to DT dir, OK)
1.355  EXT4-fs (mmcblk0p7=/metadata): mounted   (e2fsck gracefully skipped — our fix works)
1.383  EXT4-fs (dm-0=system): mounted
1.399  EXT4-fs (dm-1=system_ext): mounted
1.404  EXT4-fs (dm-2=vendor): mounted
1.409  EXT4-fs (dm-3=product): mounted
1.413  Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
       (NO second-stage init log lines at all → died before logging anything)
```

## KEY DISCOVERY: MTK ignores our boot.img cmdline
Kernel actually received (from LK/preloader, NOT our boot.img):
```
... bootopt=64S3,32S1,32S1 buildvariant=user root=/dev/ram androidboot.verifiedbootstate=orange ...
```
- Our boot.img cmdline was `bootopt=64S3,32N2,64N2 ... buildvariant=eng androidboot.selinux=permissive`.
- The LK injects **its own** cmdline; ours is dropped. So **`androidboot.selinux=permissive`
  never reaches the kernel → device boots SELinux ENFORCING.** (Matches the user's memory:
  "the kernel forces it", "never got sepolicy permissive".)
- The "~40-char cmdline budget" lore = this LK behavior. We cannot inject cmdline via boot.img.

## Diagnostics done (chroot on phone in TWRP + server)
- Init binary: 32-bit ARM, interpreter `/system/bin/bootstrap/linker`. All NEEDED libs present
  in `/system/lib`; bootstrap linker + bootstrap libs present. **Linking works** (init runs in chroot).
- **secilc compile reproduced on server SUCCEEDS** (system plat_sepolicy.cil + mapping/30.0.cil
  + system_ext + stock vendor vendor_sepolicy.cil + plat_pub_versioned.cil → valid 935KB policy,
  exit 0). Vendor sepolicy version = 30.0, our system has mapping/30.0.cil. **Versions match.**
- Full chroot (system as root + vendor/product/system_ext + dev/proc/sys): init loads policy,
  starts services. The chroot-only failures ("No precompiled sepolicy", "Failed to read
  plat_sepolicy_vers.txt", "secilc Failed to open file_contexts") are TWRP-chroot artifacts
  (missing /vendor mount and /sys/fs/selinux/null), NOT real-boot problems.

## The open question (for expert)
Why does second-stage `/system/bin/init` exit **127** within ~4ms of switch_root, logging
nothing, BEFORE the "Loading SELinux policy" line — when:
- first-stage mounted everything OK,
- the init binary links fine (proven in chroot),
- the sepolicy compiles fine (proven on server),
- exit 127 (clean exit, not SIGABRT=6) rules out the LOG(FATAL) paths (mount/exec/policy-load fail = 6)?
Candidates: (a) kernel SELinux enforcing with no policy denying the very-early second-stage
exec/op; (b) bootstrap linker fallback (no /linkerconfig/ld.config.txt) failing only in the
real early-boot mount namespace; (c) something in SetStdioToDevNull/InitKernelLogging.

## On-phone state now (ready, NOT yet booting)
- boot = LOS-built (check-free fstab); vbmeta flags-3; system rewritten complete/clean;
  vendor(enc-off)/product/system_ext intact. Phone sits in TWRP.

## Candidate next steps (no data spent yet)
1. Get REAL second-stage logging (the blocker to progress). Options: repack ramdisk to enable
   first_stage_console, or wrapper around the second-stage init exec.
2. Force SELinux permissive WITHOUT cmdline (since LK blocks it): bake permissive into the
   compiled policy, or patch init's default enforce mode, or provide a matching
   precompiled_sepolicy (eliminates boot-time compile fragility).
3. Consider using the proven tree's MATCHED vendor (noophyy) instead of stock vendor.
