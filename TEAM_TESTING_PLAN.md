# X657B — TEAM TESTING & POLISH PLAN (start here)

## STATUS: ✅ THE ROM BOOTS TO HOME. Your job = test everything + make it a clean permanent ROM.
LineageOS **18.1-20260531-UNOFFICIAL-X657B** boots fully on the Infinix X657B (MT6761, Android 11, 32-bit):
`sys.boot_completed=1`, launcher + SystemUI up, **SELinux ENFORCING**, **/data = f2fs, NON-encrypted**.
Do NOT re-architect anything below — it is the proven working recipe. Only test + polish.

## HOW TO REACH THE PHONE (adb/fastboot run on the user's Mac over a reverse SSH tunnel)
- The Mac is reachable from this server at `ssh -p 2222 brucewayne@localhost` (tunnel: server:2222 -> Mac:22).
- adb/fastboot live at `/usr/local/bin/adb` and `/usr/local/bin/fastboot` ON THE MAC.
- Server wrappers already exist: **`~/bin/padb`** = run adb through the tunnel (e.g. `padb shell getprop sys.boot_completed`).
  **`~/bin/bootwatch`** = after a reboot, auto-pulls the phone fastboot->TWRP if it bootloops; verdict in /tmp/bootwatch.result.
- If the tunnel is down, ask the user to run on their Mac: `ssh -R 2222:localhost:22 root@187.127.231.76` (phone plugged in).
- The phone is currently BOOTED to Android (adb=device). It can also be in TWRP recovery.

## THE WORKING RECIPE (never break these)
- **boot.img** = device REAL stock boot, md5 57e6f9def... = `/root/android/working_ref/boot.emmc.win`. (NOT the Flash_File ed53 one.)
- **vbmeta** = flags-3 (AVB DISABLED) = `/root/android/working_ref/vbmeta*.emmc.win`. flags-0 => MTK LK rejects.
- **APEX MUST BE FLATTENED**: stock vendor sets `ro.apex.updatable=false` and wins, so apexd runs flattened
  and exits; init bind-mounts flattened /system/apex/<name> dirs. Device tree has
  `OVERRIDE_TARGET_FLATTEN_APEX := true` in BoardConfig.mk and core_64_bit.mk removed. Updatable .apex = /apex
  empty = every service exits 127. (system.img /system/apex MUST be DIRS, not .apex files.)
- **Kernel is enforce-locked** (CONFIG_SECURITY_SELINUX_DEVELOP unset). DO NOT try to force permissive — it
  panics init. The flattened enforcing policy works (GSIs boot enforcing here too).
- **/data = f2fs, no encryption**. vendor fstab /data line has NO fileencryption/forceencrypt. If /data won't
  mount, the partition is probably ext4 from a TWRP format: dd-wipe its superblock
  (`dd if=/dev/zero of=/dev/block/by-name/userdata bs=1M count=16`) then reboot — fs_mgr (formattable)
  reformats it f2fs. (make_f2fs in TWRP fails with O_EXCL because TWRP holds the device.)

## DEPLOYED ARTIFACTS (server `/root/android/flash_build9/` unless noted)
- `system_v13.img` (md5 7a2b3b7ec69a0227d4f00d21c56e3eba) — FLATTENED apex, currently on the phone's logical
  system partition (raw fs = 968802304 = exactly the partition). Built from /root/android/lineage.
- Init on the phone still has DEBUG instrumentation (wrapinit breadcrumbs -> /metadata/wrapinit.log, and a
  klogctl dump). It works but slows boot; strip for production (see POLISH P3).
- boot 57e6 + vbmeta flags-3 already flashed.

## ===== TASKS =====

### P1 — Verify reboot persistence (do first)
1. `padb reboot` ; then poll: `padb shell getprop sys.boot_completed` until =1 (allow ~3-5 min; first boots
   do dexopt). Use bootwatch to recover if it loops.
2. Confirm launcher resumes: `padb shell dumpsys activity activities | grep -m1 ResumedActivity`.
3. PASS = boots to home unaided. Log result.

### P2 — Functional test pass (phone is booted; use adb). For EACH: record pass/fail + key logcat lines.
- **Display/UI/touch**: launcher already up (PASS baseline). Note responsiveness from user.
- **Wi-Fi**: `padb shell svc wifi enable` ; `padb shell cmd wifi status` / `dumpsys wifi | head`; scan + connect
  (ask user to tap a network). Check `logcat -d | grep -iE "wlan|wifi|wpa"` for HAL/driver errors.
- **Telephony/RIL**: `padb shell dumpsys telephony.registry | grep -iE "mServiceState|mSignalStrength"`;
  is the SIM detected? signal? try a call/SMS (ask user). `logcat -d | grep -iE "ril|telephony|modem"`.
- **Audio**: play a sound / `padb shell dumpsys audio | head`; check `logcat -d | grep -iE "audio|tinyalsa"`.
- **Sensors**: `padb shell dumpsys sensorservice | head -40` (accel/light/etc present?).
- **Camera**: `padb shell dumpsys media.camera | head`; open camera app (ask user).
- **Bluetooth**: `padb shell svc bluetooth enable` ; `dumpsys bluetooth_manager | head`.
- **GPS/Location**, **Vibrator**, **Fingerprint** (Tran FP), **Storage/MTP**, **Battery/charging**
  (`dumpsys battery`), **Brightness**, **Notifications**.
- Collect a full bugreport-ish dump: `padb shell logcat -d > /tmp/boot_logcat.txt` and `padb shell dmesg`.
- Summarize which subsystems work / fail.

### P3 — Clean production init (remove debug instrumentation)
In /root/android/lineage/system/core/init, revert the WRAPINIT additions:
- main.cpp: remove `wrapinit_log` + `wrapinit_dump_klog` functions and their includes.
- init.cpp, selinux.cpp, first_stage_init.cpp, service.cpp, action.cpp: remove the `wrapinit_log(...)` /
  "ACT/SVC/SS/S2/FSB" breadcrumb calls and the `DUMPKLOG_NOW` trigger.
- KEEP: BoardConfig OVERRIDE_TARGET_FLATTEN_APEX=true; core_64_bit.mk removed; selinux.cpp default ENFORCING.
- `mka systemimage`; verify /system/apex = DIRS only; redeploy + reboot; confirm still boots to home.

### P4 — Permanent flashable ROM
- Assemble `super_v13.img` with lpmake: partitions system(system_v13)+system_ext+product+vendor(vendor_fixed),
  group `main`, device super size 3439329280, metadata 65536 / 2 slots. (See prior super_v6 assembly in
  BUILD_FIXES.) Verify with lpdump.
- Optionally a TWRP-flashable zip. Document the flash steps: boot=57e6, vbmeta=flags-3, super=super_v13,
  then Format Data (f2fs) / dd-wipe userdata. Save to Mega `/X657B-build/roms/build-13/`.

## RULES
- Validate before flashing; flash sparingly (a human must press TWRP keys / re-tunnel if it bootloops).
- DO NOT break the working recipe (flattened apex, boot 57e6, vbmeta flags-3, enforcing, f2fs /data).
- **LOG every move** to GitHub `MostafaAshry513/device_infinix_X657B` BUILD_FIXES.md (gh api PUT) AND Mega
  (`mega-put -c`). Append, don't overwrite. The full play-by-play + root causes are in BUILD_FIXES.md and
  FINDINGS_apex_selinux.md.
- Do NOT touch Killbotv2.
