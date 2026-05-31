# AGENT HANDOFF — Infinix X657B LineageOS ROM (paste this to any agent on this server)

You are continuing a long effort to get a **full working LineageOS 18.1 ROM** booting on an
**Infinix Smart 5 X657B** (MediaTek **MT6761**, Android 11, **32-bit userspace only**, non-A/B,
dynamic partitions / `super`, 3 GB). Bootloader is unlocked. The phone is driven from a Mac over an
SSH reverse tunnel; `adb` works from THIS server (device usually sits in **TWRP recovery**).
`fastboot` is NOT available here (USB-only, on the Mac).

## THE BOOT RECIPE THAT WORKS ON THIS DEVICE (critical)
- **vbmeta MUST be flags-3 (AVB DISABLED).** flags-0 (stock) => MTK LK rejects images => logo → recovery,
  kernel never runs. Proven-good flags-3 vbmeta: `/root/android/working_ref/vbmeta*.emmc.win`.
- **boot = the device's REAL stock boot** md5 `57e6f9def...` = `/root/android/working_ref/boot.emmc.win`.
  (The Flash_File boot `ed53d6a2...` is the WRONG version — do not use.)
- Stock ramdisk first_stage_mount REQUIRES system+system_ext+vendor+product all present (not nofail).
- A GSI super boots fine with this recipe; our device LOS super is what we're getting to boot.

## CURRENT STATE (2026-05-31)
- **exit-127 SOLVED** (it was the broken boot recipe; fixed by stock boot 57e6 + flags-3 vbmeta).
- Instrumented init (`/metadata/wrapinit.log`, fsync breadcrumbs) proved init runs: first-stage →
  selinux_setup (policy loads OK) → second_stage → SecondStageMain → main loop → early services →
  then **init does a CLEAN REBOOT (`shutdown_done`) right after `boringssl_self_test32`** = bootloop.
- Cause: init.rc `boringssl_self_test32`/`_test64` have `reboot_on_failure reboot,boringssl-self-check-failed`;
  the self-test exits non-zero on-device → reboot. **boringssl_self_test32 PASSES standalone on the server
  (qemu) — libcrypto is fine** — so the on-device failure is environmental: **SELinux ENFORCING** (MTK LK
  drops our boot.img cmdline so `androidboot.selinux=permissive` never applies). Also `_test64` binary is
  missing (32-bit build but init.rc has 64-bit service → core_64_bit-vs-TARGET_ARCH=arm config conflict).
- Applied so far: removed `reboot_on_failure` from both boringssl services in the on-phone init.rc.
- **NEXT STEP: force SELinux permissive inside init** (since cmdline can't): in
  system/core/init/selinux.cpp, after `SelinuxInitialize()` loads policy, add `security_setenforce(0);`
  (and/or make the compiled policy permissive). Rebuild init, deploy, test. Then continue past whatever
  the next enforcing/HAL failure is. Longer-term: fix the 64/32 arch config.

## KEY FILES / LOCATIONS (server)
- LOS tree: `/root/android/lineage` (build: `source build/envsetup.sh; lunch lineage_X657B-eng; mka <tgt>`).
- Our LOS super: `/root/android/super_v5.img` (also on phone `/sdcard/super_v5.img`).
- Proven boot+vbmeta: `/root/android/working_ref/{boot,vbmeta,vbmeta_system,vbmeta_vendor}.emmc.win`.
- init variants + logs + ramoops + findings: `/root/android/flash_build9/` (init_s2/s3/s4 = instrumented).
- Stock firmware (recovery safety): `/sdcard/Download/Roms/INFINIX_..._Flash_File/` (on phone).
- LOS21 a-only GSI (alt path, decompressed): `/root/android/los_gsi.img`; built GSI super: `/root/android/super_gsi.img`.
- Agent memory/context: `/root/android/lineage/QWEN.md`.

## LOGS (durable — UPDATE AFTER EVERY MOVE)
- GitHub: `MostafaAshry513/device_infinix_X657B` → `BUILD_FIXES.md` (full play-by-play). Update via
  `gh api -X PUT repos/.../contents/BUILD_FIXES.md ...` (gh authed as MostafaAshry513).
- Mega: `mega-put -c BUILD_FIXES.md /X657B-build/roms/build-9-los-boot/`.

## TOOLS
- **Server-side ARM testing (no phone!):** binaries are 32-bit ARM; run them with
  `unshare -rpf --mount-proc bash -c "qemu-arm-static -L <sysroot> <sysroot>/system/bin/bootstrap/linker <sysroot>/system/bin/<binary>"`
  (the `unshare` low-PID namespace is REQUIRED — 32-bit bionic aborts if host PID > 65535). Mount our
  system: `simg2img out/target/product/X657B/system.img /tmp/s.img; mount -o ro,loop /tmp/s.img <sysroot>`.
  Use this to validate fixes BEFORE flashing to cut the push/bootloop cycle.
- Multi-model code agent (agentrouter credits): `code-agent` (any dir) / `qwen-rom` (ROM tree). Key at
  `~/.config/agentrouter/key` (replace: `printf NEWKEY > ~/.config/agentrouter/key`). Internet: `websearch "q"`.
- adb deploy of a new init WITHOUT reflashing super: `adb push init /tmp/init; adb shell 'umount /system_root;
  mount /dev/block/mapper/system /mnt/sx; cp /tmp/init /mnt/sx/system/bin/init; chcon u:object_r:init_exec:s0 ...; sync; umount /mnt/sx'`.
  Read result: `adb shell 'mount /dev/block/by-name/md_udc /mnt/md; cat /mnt/md/wrapinit.log'`.
- ramoops (kernel console of last boot, ONLY commits on panic — NOT on clean reboot/watchdog):
  `/sys/fs/pstore/console-ramoops-0`. Clear: `rm` it.

## DEVICE WORKFLOW (human-in-the-loop)
The phone bootloops on failure; a HUMAN must press the TWRP key-combo to get back to recovery for adb.
Test sparingly; prefer server (qemu) validation first. Never flash stock flags-0 vbmeta.

## RULES
- Log every move to GitHub + Mega (above).
- Do NOT work on `Killbotv2` (credential-stuffing tool) — declined.
