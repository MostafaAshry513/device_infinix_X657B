
# X657B ROM — Master Reference (2026-06-04)

Single source of truth for the Infinix X657B LineageOS 18.1 project. Read this first; it replaces the long scattered notes.

## 1. Device & HARD constraints (don't re-litigate)
- Infinix X657B (Smart 5), **MT6761**, **32-bit ARM only** (armeabi-v7a), 3 GB RAM, non-A/B, **dynamic partitions** (super), **bootloader UNLOCKED** (verifiedbootstate=orange, can't relock).
- **Stuck on Android 11** — vendor blobs/kernel only support A11. NO Android 12+ (so NO Material You / modern system UI; the dated Settings/status-bar look CANNOT be changed).
- Capped, confirmed-impossible (stop trying):
  - **Custom from-source kernel** — Infinix never released source; generic MT6761 tree lacks the `nt36525b` display panel driver + 75 `CONFIG_TRAN_*` hooks → boots but black screen. (qwen kernel agent in tmux `kernel`.) PROGRESS 2026-06-04: agent ported the `nt36525b` LCM panel driver from Vivo Y81 (4.9.77) → candidate C `boot_C_lcm.img`. **On-device test (flashed to boot=mmcblk0p28 via TWRP; `fastboot boot` is UNSUPPORTED on this MTK LK): LK printed "cmdline overflow" → aborted before kernel.** Root cause: boot-image header cmdline is fine (40 chars = stock) but the **from-source `mt6761.dtb` `/chosen/bootargs` is bloated** (slub_debug, page_owner, swiotlb, console=ttyS0, literal tabs) → LK appends runtime androidboot.* → overflows LK buffer. Fix dispatched to agent: pack new zImage with the **stock DTB + stock ramdisk extracted from `flash_build9/boot_orig_backup.img`** (header v2) → candidate D pending. Kernel test recovery: backup boot first (`dd .../by-name/boot`), restore from `boot_orig_backup.img` (57e6) via TWRP if it fails.
  - **Modern launcher owning recents on A11** — no 3rd-party APK can own recents (MATCH_SYSTEM_ONLY + QuickStep AIDL); Lawnchair can't build in-tree (Gradle/Compose); the "Lawnchair+QuickSwitch+Magisk" method is Android-12 + root + unvalidated on A11. Only Trebuchet/Launcher3 (pkg com.android.launcher3) own recents on A11.
  - **Pixel Launcher** — gated Google APK + arm64 + wrong SystemUI AIDL.
  - **Strong/hardware Play Integrity** — unlocked bootloader = permanent fail. Prop-level spoof (Magisk+PIF) can pass BASIC/many apps, NOT hardware attestation. reveny Native Root Detector is research-grade = unbeatable.

## 2. PROVEN flash recipe (this device)
- boot = **stock 57e6** (`/root/android/flash_build9/boot_orig_backup.img`, md5 57e6f9def…) — the LOS-built/custom kernels do NOT boot; only this stock boot works.
- vbmeta = **flags-3 (AVB disabled)** from `/root/android/working_ref/vbmeta*.emmc.win`.
- super = our assembled super (system+system_ext+product+vendor).
- /data: zero userdata+metadata superblocks → fs_mgr reformats f2fs on boot (= "Format Data").
- APEX must be **flattened** (OVERRIDE_TARGET_FLATTEN_APEX=true) — vendor ro.apex.updatable=false wins.

## 3. Build pipeline (commands)
```
cd /root/android/lineage && source build/envsetup.sh && lunch lineage_X657B-user
make installclean && mka target-files-package otatools          # full build
# release-keys re-sign (MUST use the BUILT host binaries — system py3.12 lacks 'imp'):
out/host/linux-x86/bin/sign_target_files_apks -d ~/.android-certs <TF>.zip /root/android/signed-tfNN.zip
out/host/linux-x86/bin/img_from_target_files /root/android/signed-tfNN.zip /root/android/signed-imgNN.zip
# extract system/product/system_ext.img from signed-imgNN.zip -> /root/android/signedNN/
bash /root/android/assemble_super_vNN.sh                          # lpmake super (group main, super 3439329280)
```
- Signing keys: `~/.android-certs/` AND `device/infinix/X657B/security/` (releasekey/platform/shared/media/networkstack + a copied AOSP **testkey** — required or mac_permissions build fails). PRODUCT_DEFAULT_DEV_CERTIFICATE set in lineage_X657B.mk.
- **super assembly gotcha**: sub-images are SPARSE; `simg2img` to RAW first (use `out/host/linux-x86/bin/simg2img`, NOT the obj/ one — it lacks libc++); lpmake partition size must be the RAW size rounded to 4096.
- **CRITICAL — the FINAL super must be RAW before chunking for the dd installer.** `lpmake --sparse` outputs a SPARSE super (magic `3aff26ed`). The shell installer `dd`s chunks RAW, so a sparse super → invalid super metadata → dynamic partitions don't mount → **BOOTLOOP**. Build-18 (booted) chunks are RAW (`00000000`, total = full 3439329280). MUST `simg2img super_vNN.img super_vNN_raw.img` then split the RAW (build20_installer.sh originally skipped this = build-20 bootloop). On-device recovery (no re-transfer): the partition holds the valid sparse → `mke2fs` userdata scratch, `simg2img /dev/block/by-name/super /scratch/raw.img`, `dd raw.img → super`, then zero userdata/metadata superblocks.
- **Flashable zip gotcha**: TWRP `unzip` std::bad_alloc on a huge entry → **split super into 256MB chunks** (`super.part.NN`); shell update-binary streams: `for c in $(unzip -l ZIP|grep -oE 'super\.part\.[0-9]+'|sort -u); do unzip -p ZIP $c; done | dd of=$BD/super bs=8M`. build-18 installer also auto-formats data.

## 4. Current shipped build = build-18 (Mega /X657B-build/roms/build-18/)
`X657B-build18-installer.zip` (md5 c3a28d217753ff3de38c118e69575c94, chunked, AUTO-FORMATS data). Contains, all verified:
- ro.build.tags=**release-keys**; GApps baked (GmsCore+Play Store+Velvet+sync adapters + privapp-permissions/sysconfig); de-Googled F-Droid removed.
- Lawnchair + Lawnicons + Arcticons; **Trebuchet = recents engine**; OpenCamera; Smartspacer.
- low_ram=false (split-screen), gestures, OTG (android.hardware.usb.host feature; host works for drives/mice — MTP-phone browsing is an Android limit), TWRP-survival (install-recovery.sh neutralized in vendor), status-bar clock cutout fix.

## 5. Device-tree customizations (device/infinix/X657B/)
- `lineage_X657B.mk`: PRODUCT_PACKAGES += Cromite, Fossify {Phone,Contacts,Messages,Gallery,FileManager,Calculator,Clock,Calendar}, Auxio, Lawnchair, Lawnicons, Arcticons, OpenCamera, Smartspacer, GApps modules. PRODUCT_DEFAULT_DEV_CERTIFICATE.
- `fossapps/Android.mk`: PRESIGNED prebuilt modules for the above (LOCAL_OVERRIDES_PACKAGES replaces stock apps — the RELIABLE debloat; filter-out is a NO-OP on inherited pkgs).
- `gapps/` + `gapps/Android.mk`: GApps APKs as BUILD_PREBUILT modules (APKs can't be in PRODUCT_COPY_FILES); non-apk GApps files via PRODUCT_COPY_FILES in device.mk.
- `overlay/.../config.xml`: config_navBarInteractionMode=2 (gesture), config_supportsMultiWindow=true, cleared cutout, config_defaultNightMode=2 (didn't apply — LOS overrides), config_defaultDialer/Sms=Fossify. `colors.xml`: teal accent (ignored by LOS Styles). `drawable-nodpi/default_wallpaper.png`.
- `security/`: signing keys. `BoardConfig.mk`: OVERRIDE_TARGET_FLATTEN_APEX, super sizes, SELINUX_IGNORE_NEVERALLOWS conditional. sepolicy/private: many neverallow fixes (see git).
- **vendor patch** = `/root/android/raw/vendor_v14.img` (low_ram=false + install-recovery.sh→exit0; SELinux labels fixed via `debugfs ea_set` since host has no SELinux). Reused for every super.

## 6. Live-settings (NOT bakeable cleanly; user re-applies post-flash, or set via adb): dark `cmd uimode night yes`; teal `cmd overlay enable org.lineageos.overlay.accent.cyan`; profiles `settings put system system_profiles_enabled 1` (THIS = what user means by "no profiles" — app installed but disabled); home `cmd package set-home-activity <pkg>/...`.

## 7. Infra
- **adb to phone** = SSH hop: user runs `ssh -R 2222:localhost:22 root@187.127.231.76` from Mac (user `brucewayne`, adb at `/usr/local/bin/adb`). It DROPS often → reconnect. Reach via ControlMaster: `ssh -p 2222 -o ControlPath=/tmp/macN.sock brucewayne@localhost '/usr/local/bin/adb …'`. Server's own adb must be killed (frees 5037). Data wipe resets USB-debugging (user re-enables).
- **Give phone internet over USB (no WiFi/SIM)** = gnirehtet reverse-tether (Mac has NO Java/brew → use portable JRE; Mac is x86_64 on ethernet). Already staged in Mac `~/rt/`: JRE17 (`jdk-17.0.19+10-jre/Contents/Home/bin/java`) + `gnirehtet-java/`. Run: `cd ~/rt/gnirehtet-java && PATH=/usr/local/bin:$PATH nohup <JRE>/java -jar gnirehtet.jar run >~/rt/relay.log 2>&1 &` (apk already installed; creates tun0 10.0.0.2, no VPN-consent tap needed, validates). Survives SSH drop; dies on USB unplug → rerun. Plain adb-reverse+http_proxy does NOT work (phone has "Active default network: none" → apps refuse). Cleanup: `adb shell settings put global http_proxy :0`.
- **Mega**: logged in (mostafaashry115@gmail.com), `mega-put`. Builds in /X657B-build/roms/build-NN/, gapps in /X657B-build/gapps/.
- **GitHub**: gh authed as MostafaAshry513. Kernel repo `x657b_kernel_4.19`; device repo `device_infinix_X657B`.
- **Kernel agent**: qwen in tmux session `kernel` (porting hunt, logs to GitHub+Mega, never flashes untested).
- **Assets staged**: /root/android/build16_assets (Magisk-v30.7.apk, PlayIntegrityFork-v16.zip, Inter font), /root/android/launcher2_research (Lawnchair-as-system refs), /root/android/MindTheGapps-11-arm.zip.

## STATUS 2026-06-04 (build-20 staged, awaiting flash)
- **build-20 = BUILT + release-keys signed + chunked auto-format installer** `X657B-build20-installer.zip` (md5 `d6ce5af2590713a6af3e52e110969448`, 2.2G). Contains super_v20 with **vendor_v19 (reveny detector fix: com.reveny.nativecheck in arc.ini CUSTOMIZE_BLACK)**, stock boot, Lawnchair-a11 owns recents, CameraGo. Saved on phone `/sdcard/build20.zip` (md5 verified), Mac `/tmp/build20.zip`, server `/root/android/`.
- **TO FLASH (user deferred to next session):** `adb reboot recovery` → `adb shell twrp install /sdcard/build20.zip` (or push to /sdcard if wiped) → reboot. Auto-wipes data. Then verify: detector OPENS, Lawnchair owns recents (no launcher switch), CameraGo works. Restart gnirehtet for phone internet after.
- **Detector debug finding (no-root):** app shows a toast then UI hangs → SIGKILL right after libMEOW injects → libMEOW GL-injection conflict (vendor_v19 arc.ini blacklist targets this; verify on flash).
- **Kernel:** candidate C failed on-device (LK "cmdline overflow" from from-source DTB bootargs); agent rebuilding **candidate D** with stock DTB+ramdisk. Stock boot restored, phone healthy.

## 8. PENDING TASK (user's current order — do all, reply only when done)
1. **FIRST: fix reveny Native Root Detector (com.reveny.nativecheck) crash** — must OPEN and show root-detection results in ANY state. It hangs on launch → SIGKILL; suspected Transsion **libMEOW** (ro.hardware.egl=meow, libMEOW_gift.so injected into every app via /vendor/etc/arc.ini). Fix = vendor patch: add the pkg to arc.ini `[CUSTOMIZE_BLACK]` (or neutralize libMEOW_gift). Verify (root via Magisk to test live, or flash).
2. **Launcher**: REMOVE Trebuchet AND Lawnchair (+Lawnicons) from the tree entirely; find ANOTHER launcher that works with navigation. (Hard: only com.android.launcher3-based owns recents on A11; search for a different modern in-tree A11 Launcher3 fork, else this is the wall.)
3. **Camera**: REMOVE OpenCamera from the tree; find a full **GCam** (MGC) that works on MT6761/A11 (uncertain — Camera2 HAL limits).
4. Then the rest of the ROM; build-19; sign; super; chunked auto-format installer; push to phone.
