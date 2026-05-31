# AGENT HANDOFF — Infinix X657B LineageOS ROM (stable resume brief; works from ANY stop point)

## ✅ 2026-05-31: THE ROM NOW BOOTS TO HOME. Next work = TEST + POLISH, not bring-up.
LineageOS 18.1-20260531-UNOFFICIAL-X657B boots fully (boot_completed=1, launcher up, SELinux ENFORCING,
/data f2fs non-encrypted). **READ `/root/android/TEAM_TESTING_PLAN.md` FIRST — it has the exact next tasks,
commands, the working recipe (don't break it), and how to reach the phone.** Then this file + BUILD_FIXES.md.

You are continuing a long effort to boot a **full working LineageOS 18.1 ROM** on an **Infinix Smart 5
X657B** (MediaTek **MT6761**, Android 11, **32-bit userspace only**, non-A/B, dynamic partitions/`super`,
3 GB, bootloader unlocked). The phone is driven from a Mac over an SSH reverse tunnel. adb/fastboot run ON
THE MAC (`ssh -p 2222 brucewayne@localhost /usr/local/bin/{adb,fastboot}`); server wrappers `~/bin/padb`
and `~/bin/bootwatch`. The phone may be booted to Android (adb=device) or in TWRP recovery.

## ⭐ STEP 1 — LEARN THE CURRENT STATE (do this first, every time)
The live state is ALWAYS at the **end of `/root/android/BUILD_FIXES.md`** (mirrored to GitHub
`MostafaAshry513/device_infinix_X657B` and Mega `/X657B-build/roms/build-9-los-boot/`). It is updated
after EVERY move. **Read its last ~5 entries** — the most recent one states what was just done and the
NEXT STEP. Resume from there. If mid-debug, also read the phone's `/metadata/wrapinit.log` (init
breadcrumbs) and `/root/android/flash_build9/` (latest builds, logs, ramoops). Agent context also in
`/root/android/lineage/QWEN.md`.

## THE BOOT RECIPE THAT WORKS (do not relearn the hard way)
- **vbmeta MUST be flags-3 (AVB DISABLED).** flags-0 => MTK LK rejects images => logo→recovery, no kernel.
  Proven flags-3 vbmeta: `/root/android/working_ref/vbmeta*.emmc.win`.
- **boot = device REAL stock boot** md5 `57e6f9def...` = `/root/android/working_ref/boot.emmc.win`
  (NOT the Flash_File boot `ed53...`).
- Stock ramdisk first_stage_mount needs system+system_ext+vendor+product all present (not nofail).
- Never flash stock flags-0 vbmeta. Format /data on first boot.

## KEY FILES (server)
- Tree: `/root/android/lineage` — build: `source build/envsetup.sh; lunch lineage_X657B-eng; mka <tgt>`.
- Our LOS super: `/root/android/super_v5.img` (and phone `/sdcard/super_v5.img`).
- Proven boot+vbmeta: `/root/android/working_ref/`.
- Builds/logs/ramoops/init variants: `/root/android/flash_build9/`.
- Stock firmware (recovery safety): phone `/sdcard/Download/Roms/INFINIX_..._Flash_File/`.

## TOOLS
- **Server ARM testing (NO phone — use to validate before flashing):** binaries are 32-bit ARM; run via
  `unshare -rpf --mount-proc bash -c "qemu-arm-static -L <sysroot> <sysroot>/system/bin/bootstrap/linker <sysroot>/system/bin/<bin>"`
  (the unshare low-PID namespace is REQUIRED; 32-bit bionic aborts if host PID>65535). Mount system:
  `simg2img out/target/product/X657B/system.img /tmp/s.img; mount -o ro,loop /tmp/s.img <sysroot>`.
- Multi-model code agent: `code-agent` (any dir) / `qwen-rom` (ROM tree); key `~/.config/agentrouter/key`
  (replace: `printf NEWKEY > ~/.config/agentrouter/key`). Internet helper: `websearch "query"`.
- Deploy a new init WITHOUT reflashing super: `adb push init /tmp/init; adb shell 'umount /system_root;
  mount /dev/block/mapper/system /mnt/sx; cp /tmp/init /mnt/sx/system/bin/init;
  chcon u:object_r:init_exec:s0 /mnt/sx/system/bin/init; chmod 0755 ...; sync; umount /mnt/sx'`.
  Read init breadcrumbs: `adb shell 'mount /dev/block/by-name/md_udc /mnt/md; cat /mnt/md/wrapinit.log'`.
- ramoops (last boot kernel console; commits ONLY on panic, not clean reboot/watchdog):
  `/sys/fs/pstore/console-ramoops-0` (clear with `rm`).

## WORKFLOW / RULES
- Prefer server (qemu) validation; flash the phone sparingly (a human must press the TWRP key-combo to
  recover after a bootloop). Test on phone only when a fix looks good on the server.
- **Log every move to GitHub + Mega** (update BUILD_FIXES.md: `gh api -X PUT repos/$REPO/contents/BUILD_FIXES.md ...`
  then `mega-put -c BUILD_FIXES.md /X657B-build/roms/build-9-los-boot/`). This file IS the handoff state.
- Do NOT work on `Killbotv2` (credential-stuffing tool) — declined.
