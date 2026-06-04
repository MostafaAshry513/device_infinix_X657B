# X657B ROM — Master Reference (2026-06-04)

Single source of truth for the Infinix X657B LineageOS 18.1 project. Read this first; it replaces the long scattered notes.

## 1. Device & HARD constraints (don't re-litigate)
- Infinix X657B (Smart 5), **MT6761**, **32-bit ARM only** (armeabi-v7a), 3 GB RAM, non-A/B, **dynamic partitions** (super), **bootloader UNLOCKED** (verifiedbootstate=orange, can't relock).
- **Stuck on Android 11** — vendor blobs/kernel only support A11. NO Android 12+ (so NO Material You / modern system UI; the dated Settings/status-bar look CANNOT be changed).
- Capped, confirmed-impossible (stop trying):
  - **Custom from-source kernel** — Infinix never released source; generic MT6761 tree lacks the `nt36525b` display panel driver + 75 `CONFIG_TRAN_*` hooks → boots but black screen. (qwen kernel agent still hunting a sibling-source port; long shot.)
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
- **Mega**: logged in (mostafaashry115@gmail.com), `mega-put`. Builds in /X657B-build/roms/build-NN/, gapps in /X657B-build/gapps/.
- **GitHub**: gh authed as MostafaAshry513. Kernel repo `x657b_kernel_4.19`; device repo `device_infinix_X657B`.
- **Kernel agent**: qwen in tmux session `kernel` (porting hunt, logs to GitHub+Mega, never flashes untested).
- **Assets staged**: /root/android/build16_assets (Magisk-v30.7.apk, PlayIntegrityFork-v16.zip, Inter font), /root/android/launcher2_research (Lawnchair-as-system refs), /root/android/MindTheGapps-11-arm.zip.

## 8. PENDING TASK (user's current order — do all, reply only when done)
1. **FIRST: fix reveny Native Root Detector (com.reveny.nativecheck) crash** — must OPEN and show root-detection results in ANY state. It hangs on launch → SIGKILL; suspected Transsion **libMEOW** (ro.hardware.egl=meow, libMEOW_gift.so injected into every app via /vendor/etc/arc.ini). Fix = vendor patch: add the pkg to arc.ini `[CUSTOMIZE_BLACK]` (or neutralize libMEOW_gift). Verify (root via Magisk to test live, or flash).
2. **Launcher**: REMOVE Trebuchet AND Lawnchair (+Lawnicons) from the tree entirely; find ANOTHER launcher that works with navigation. (Hard: only com.android.launcher3-based owns recents on A11; search for a different modern in-tree A11 Launcher3 fork, else this is the wall.)
3. **Camera**: REMOVE OpenCamera from the tree; find a full **GCam** (MGC) that works on MT6761/A11 (uncertain — Camera2 HAL limits).
4. Then the rest of the ROM; build-19; sign; super; chunked auto-format installer; push to phone.
