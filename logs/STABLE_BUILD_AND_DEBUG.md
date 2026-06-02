# X657B — Stable build + on-device debug log (2026-06-02)

All build/debug logs now live in this `logs/` folder (moved out of repo root):
`logs/BUILD_FIXES.md` (full bring-up play-by-play), `logs/FINDINGS_apex_selinux.md` (apex/SELinux root cause),
and this file. Kernel build logs live in the separate kernel repo (MostafaAshry513/x657b_kernel_4.19, BUILD_LOG.md).

## Recap: where we are
The **eng/debug** ROM (build-13) boots fully to the LineageOS launcher (boot_completed, /data f2fs non-encrypted,
SELinux enforcing). We are now producing the **stable user build** + on-device functional debugging.

## 1. Cleanup done (2026-06-02)
- Killed stale 13h qwen/openrouter sessions (superseded by DeepSeek config).
- Cleared /tmp scratch (old_sys*.raw, sys*.raw, *.b64, stale qemu mounts) → freed ~8 GB.

## 2. Stable build-14 (USER variant) — in progress
- **Variant:** `lunch lineage_X657B-user` (ro.debuggable=0, no adb-root, test-keys signing).
- **Removed debug instrumentation:** `git checkout system/core/init/{action,init,main,selinux,service}.cpp`
  → clean upstream init (selinux.cpp back to stock ENFORCING default; no wrapinit/klog breadcrumbs).
- **Launcher = Lawnchair 14 Beta 3** (app.lawnchair, versionCode 14000203, minSdk 26 → OK on A11). Added as
  prebuilt: `device/infinix/X657B/prebuilt/Lawnchair/` (PRESIGNED, priv-app, `LOCAL_OVERRIDES_PACKAGES :=
  Trebuchet TrebuchetQuickStep TrebuchetQuickStepGo Launcher3 Launcher3QuickStep`). Lawnchair 12.x stable has
  no GitHub APK assets (tags only); 15 targets Android 16 — 14-beta3 is the best A11-compatible build.
- **Debloat** (in lineage_X657B.mk, `filter-out` after inherits — safe no-op if absent):
  Jelly, Eleven, Recorder, Etar, Profiles, Updater, Seedvault, EasterEgg, Trebuchet*. Kept all essentials
  (Dialer/Contacts/Messaging/Settings/Camera/Gallery/Clock/Calculator/keyboard/WebView/telephony/providers).
- Building systemimage+productimage+system_extimage → then assemble super_v14 + deploy (boot 57e6, vbmeta
  flags-3, /data f2fs unchanged). Log: flash_build9/build_v14_user.log.

## 3. On-device app/network debug (eng ROM, 2026-06-02)
- **"App not working" = NO NETWORK, not an app bug.** Wi-Fi was DISABLED → DNS `EAI_NODATA` → every
  internet app (3 seen) failed. Enabling Wi-Fi → connected to AP, got IP 192.168.1.7, **VALIDATED** internet
  (ping 8.8.8.8 + google.com OK). So app failures were purely the Wi-Fi being off. WLAN works (gen4m driver,
  wpa_supplicant/wificond/wifi_hal_legacy all running).
- **"Native Detector" (`com.reveny.nativecheck`)** launches, shows UI ~2s, then **SIGKILL (signal 9) — it
  self-terminates on root detection.** It's an anti-tamper native detector (libreveny.so); Magisk is blatantly
  present (`/debug_ramdisk/magisk`, `su` + magisk tmpfs over `/system/xbin`, com.topjohnwu.magisk app, boot is
  Magisk-patched). NOT a ROM bug — the app is working as designed (detecting our root).

## 4. Play Integrity — why it's "all bad" + fix path
Factors: verifiedbootstate=**orange** (unlocked), flash.locked=0, **test-keys**, debuggable, Magisk visible.
Magisk 30.7 present but **Zygisk is OFF** → the DenyList (already has com.reveny.nativecheck, krypton.tbsafetychecker,
GMS ims) is **inert**. Only module = `hosts` (no Play Integrity Fix).
Fix path (personal-device, legitimate): enable **Zygisk** → DenyList activates; add **Play Integrity Fix (PIF)**
module + **Shamiko**; Enforce DenyList; add GMS. Realistic outcome: Play Integrity **BASIC + DEVICE pass**
(STRONG impossible on unlocked bootloader). reveny's native detector may STILL detect (purpose-built to beat
DenyList) — that one is the hardest target.

## 5. GCam feasibility
Camera HAL = **HAL3 v3.6** (Camera2-capable, 2 cameras); vendor already whitelists **com.google.camera** in
`persist.vendor.camera.privapp.list`. Level likely Camera2 LIMITED (typical MT6761) → **official Pixel GCam
won't run** (Pixel-locked), but an **MTK GCam PORT** (MGC/BSG/Parrot) has a good chance. Plan: keep
GoogleCameraGo as built-in default; sideload-test a GCam MTK port; bake in later if one works well.

## 6. Kernel build (separate, autonomous)
DeepSeek agent building the kernel from source (kernel_x657b, 4.19.325). Root cause of prior GCC failure:
GNU `as` `.type @object` on ARM → switch to **AOSP clang 11** (clang-r383902b1, integrated assembler). Running
fire-and-forget; logs to kernel repo BUILD_LOG.md + Mega /X657B-build/kernel/.
