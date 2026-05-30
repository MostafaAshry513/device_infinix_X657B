# X657B LineageOS 18.1 — Boot Bring-up Progress Log

Live log of the boot debugging effort. Most recent entries at top.

## Device facts
- Infinix X657B (Smart 5), MT6761, ARMv7 32-bit, Android 11, non-A/B, dynamic partitions
- super = 3.44GB (system/system_ext/vendor/product), Magisk-patched boot
- Boot chain: MTK LK bootloader → kernel → MagiskInit → real init (first_stage_mount → switch_root → second stage)

## CRITICAL CONSTRAINTS DISCOVERED
1. **Boot.img cmdline hard limit ≈ 40 chars.** MTK LK bootloader concatenates boot.img cmdline with its own; >40 chars → "cmdline overflow" → bootloader REFUSES to boot kernel.
   - WORKS: `androidboot.selinux=permissive` (30), stock `bootopt=64S3,32S1,32S1 buildvariant=user` (40)
   - OVERFLOWS: 41+ chars (e.g. adding ` loglevel=7`)
2. **super*.img files are Android SPARSE format** — flash with on-device `simg2img /sdcard/X.img /dev/block/by-name/super`, NEVER raw dd.
3. **simg2img does NOT overwrite "don't-care" sparse regions** — manual ext4 edits in free-space blocks survive a reflash.
4. **init force-mounts /metadata in first stage** for dynamic partitions REGARDLESS of fstab `first_stage_mount` flag removal. switch_root then must move /metadata → /system/metadata.
5. **SELinux is kernel-enforced** — cannot setenforce 0 from TWRP; permissive must come via cmdline.
6. **ramoops staleness**: console-ramoops-0 only refreshes when the kernel actually boots. Overflow boots (no kernel) leave stale ramoops. Verify freshness by checking the cmdline string embedded in the ramoops dump.

## CURRENT BLOCKER
`init: Unable to move mount at '/metadata': No such file or directory` → kernel panic at ~1.4s during switch_root.
- /system/metadata directory WAS manually created in the ext4 (verified valid, traversable, e2fsck clean).
- Panic PERSISTS even with the directory present — root cause still under investigation.
- NOTE: last confirmed-fresh ramoops was from a long-cmdline boot; need a fresh 30-char-cmdline boot log to confirm whether the dir actually resolved it.

## Partition state (current)
| Partition | Content |
|---|---|
| boot | boot-final.img, cmdline patched to `androidboot.selinux=permissive` |
| super | super-hybrid.img (build 6) via simg2img + manual /system/metadata dir |
| vbmeta / vbmeta_system / vbmeta_vendor | all zeroed (AVB disabled) |
| dtbo | stock (untouched) |

## How /system/metadata was created (raw ext4 surgery from TWRP)
Because mkdir failed (RO + kernel SELinux + group-0 ENOSPC), edited the ext4 directly:
- Allocated free inode 2669 (group 0) + free block 147278 (group 4)
- Built dir inode (extent-mapped) + dir data block (. and ..)
- Added 'metadata' dirent to root dir block 508 (stole spare from 'vendor' entry)
- Updated inode/block bitmaps, BGD counts, superblock counts
- Fixed uninit_bg: decremented bg_itable_unused, recomputed GDT csums → e2fsck clean

## Build history (from prior sessions)
- Build 1-3: BoardConfig iterations (AVB, SELinux, dynamic partitions)
- Build 4: VINTF manifest fix (was 25s init halt)
- Build 5 (super-fixed, May 27): reached switch_root, /metadata issue
- Build 6 (super-hybrid, May 28): user reports reached ~9.19s then HANG (past switch_root!) — implies a working config existed

## Timeline (this session, newest first)
- Set 30-char cmdline; reflashed super-hybrid clean; confirmed /system/metadata persists; STILL overflow on 41-char attempts
- Created /system/metadata via raw ext4 surgery; e2fsck clean; still /metadata panic
- Removed first_stage_mount from ramdisk fstab (both copies) — init still force-mounts metadata
- Patched boot cmdline for permissive SELinux (multiple overflow iterations)
- Identified sparse-image + wrong-boot.img issues; switched to boot-final + simg2img

---
## EVALUATION (root cause found)
**The system image (super-hybrid) is MISSING required root mountpoint directories: `/metadata` and `/tranfs`.**
A correctly-built Android 11 system image MUST contain these empty dirs so first-stage init's `switch_root` can move the /metadata mount into /system/metadata. The "hybrid" image build dropped them → switch_root ENOENT → panic at ~1.4s.

**Why our manual fix kept "failing":** Every `simg2img` reflash of super-hybrid OVERWRITES root dir block 508 with the original (no-metadata) version, wiping our hand-added dir. The "it persisted" readings were stale dm-0 page cache. And every ramoops we read was stale (long pre-fix cmdline) because overflow/early-fail boots never refreshed it. Net: a clean "add /metadata + DON'T reflash + fresh log" attempt was never actually completed.

**Build-server facts:** 362GB free disk, 8 cores / 31GB RAM, GitHub reachable from SERVER (server internet is separate from the user's metered tunnel — only adb push/pull over the tunnel costs the user's GB).

## TWO PATHS
- PATH A (surgical, minutes, no user internet): add /metadata to existing super-hybrid via ext4 surgery, do NOT reflash super after, boot, capture fresh log. Directly fixes root cause; likely exposes the next issue (the original ~9s hang).
- PATH B (proper build, hours, server internet): set up LOS 18.1 build env on server, sync source (~100GB server BW, ~250GB disk), populate missing prebuilts/ + sepolicy/, build a correct super.img with proper mountpoints, push only final ~2GB image over tunnel. Robust/reproducible; large effort + iteration.

---
## PATH B IN PROGRESS — proper source build
- Build env installed (OpenJDK 11, repo 2.54, all AOSP deps) ✓
- repo init lineage-18.1 --depth=1; local_manifest added for device + vendor trees ✓
- repo sync running (throttled, j5, within 70% resource budget) — server internet, not user's tunnel
- Prebuilts EXTRACTED from stock boot.img (Nov 2022) → staged in /tmp/prebuilts:
  - kernel (10548720 bytes, raw ARM Image)
  - dtb (125101 bytes, valid FDT d00dfeed @ boot.img offset 11294784)
  - dtbo.img (8MB, dumped from phone /dev/block/by-name/dtbo)
- NEXT: create sepolicy/ dir, copy prebuilts into device tree, build lineage_X657B
- NOTE: building from clean LOS source should AUTO-create proper root mountpoints (/metadata etc.), fixing the switch_root root cause without manual ext4 surgery.

---
## BUILD SUCCESS (system.img) — 2026-05-30
- Fixed root cause: lineage_X657B.mk now inherits handheld_system.mk + telephony_system.mk
  → PRODUCT_BOOT_JARS 0→12, hiddenapi-stub-flags.txt builds, no more "No boot DEX files".
- `mka systemimage` → build completed successfully (50:41). system.img = 617MB.
- hiddenapi-stub-flags.txt = 40MB (the step that failed at 99% before — now passes).
- NOW building system_ext + product images, then assembling super.img.
- Architectural note: we now have a real Android 11 handheld base + Go trim layer.
  Full non-Go Android 11 later = drop go_defaults/common_mini_go (~1-line change).
