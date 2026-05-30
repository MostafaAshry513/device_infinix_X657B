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
