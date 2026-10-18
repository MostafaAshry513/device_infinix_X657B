# DETECTOR FIX — com.reveny.nativecheck on X657B (build-20 → build-22)

## KILL ANALYSIS: Thorough offline investigation

### What we proved it's NOT
1. **NOT `libreveny.so` self-kill**: Library has ZERO direct `svc 0` calls (objdump -d confirmed).
   `kill`/`exit`/`abort` strings are from C++ stdlib infrastructure (terminate handler, atexit).
2. **NOT Java `finish()` or `System.exit()`**: No such calls in MainActivity or detection flow (smali confirmed).
3. **NOT update-installer activity launch**: `startActivity(MANAGE_UNKNOWN_APP_SOURCES)` and
   `startActivity(ACTION_VIEW .apk)` are in `UpdateCheck` lambdas — only triggered when update
   check SUCCEEDS. Network failure (UnknownHostException) is caught, path not taken.
4. **NOT OOM/lmkd**: `dmesg` clean, `logcat -b all` no lmkd messages, oom_score_adj stays 0.
5. **NOT pa/fg timeouts** (PAUSE_TIMEOUT, LAUNCH_TICK, TOP_RESUMED_STATE_LOSS all 3000ms).

### What libreveny.so actually does (from static analysis)
- 2 JNI exports: `getDetections(Context, PackageManager, bool, bool)` and `isoServiceExecute(Context, int)`
- NO `JNI_OnLoad` — no code runs at library load time
- Spawns 2 C++ threads inside `getDetections` (`$_0` and `$_1`)
- Uses `pthread_create`, `pthread_detach`, `pthread_mutex_lock`
- Uses `ptrace` and `process_vm_readv` for detection (reads other processes' memory)
- Uses `MountInfo::CheckMounts` — scans /proc/mounts for Magisk mounts
- Uses `ProcessDescriptors` — scans /proc/self/fd
- NO direct syscalls (0 `svc 0` instructions in entire 833KB binary)
- NO network code (no URL strings in library)

### What the DEX code does on launch
1. `Native.<clinit>` loads `libreveny.so` via `System.loadLibrary("reveny")`
2. `MainActivity.onCreate` sets up Compose UI (takes ~800ms, causes "Skipped 55 frames")
3. Background thread runs `getDetections()` → spawns 2 native detection threads
4. Concurrently, `UpdateCheck` fetch to raw.githubusercontent.com runs on background thread
5. Detection results return → `showToast()` displays result Toast
6. Update check fails (no network) → exception caught, no update path taken

### OomAdj at death: 200 (PERCEPTIBLE_APP_ADJ) = RECALCULATED AT DEATH
The OomAdj sampling showed 0 (foreground) until 1400ms, then GONE at 1600ms.
The death event reports OomAdj=200 because the AM recalculates AFTER process death —
with no living activity component, adj falls from 0 to 200.

### Most likely kill source
The ~1.5-1.9s death timing maps to NO known Android timeout (PAUSE=3000ms patched,
CONTENT_PROVIDER=10000ms, SERVICE=20000ms, KEY_DISPATCHING=5000ms, ANR=5000ms).

The consistent 1.5-1.9s window + immediate OomAdj recalculation + NO native self-kill
suggests the process is SIGKILL'd by the ActivityManager as part of a cleanup/restart
cycle: the process is killed when the system decides the activity is stuck in startup,
then the process is restarted (multiple PIDs observed). The timeout patch covers the
named constants but may not cover all internal AMS paths.

---

## BUILD-22 FIX PLAN: Focus on making app start FAST enough

Since the kill source is system-side and avoiding it requires making the app start
faster than any hidden timeout, the fix is to ensure the app's DEX is fully pre-compiled
and no runtime initialization blocks the main thread.

### Fix 1: Stub libMEOW_gift.so (already in tree)
File: `proprietary/vendor/lib/egl/libMEOW_gift.so`
Replace with 84-byte stub ELF. Original at `.orig`.

### Fix 2: Fix dex2oat CPU set (already found)
File: `system.prop`
`dalvik.vm.dex2oat-cpu-set=0,1,2,3,4,5,6,7` → `0,1,2,3`

### Fix 3: Framework timeout patch (already built)
Files:
- `frameworks/base/.../wm/ActivityRecord.java:384` — PAUSE_TIMEOUT: 500→3000
- `frameworks/base/.../wm/ActivityRecord.java:387` — LAUNCH_TICK: 500→3000
- `frameworks/base/.../wm/ActivityStackSupervisor.java:177` — TOP_RESUMED_STATE_LOSS_TIMEOUT: 500→3000

### Fix 4: Pre-compile app at build time (NEW)
Add to `device.mk`:
```
PRODUCT_DEXPREOPT_SPEED_APPS += com.reveny.nativecheck
```
Also add app to the `PRODUCT_SYSTEM_DEFAULT_PROPERTIES` so it's compiled during dexpreopt:
```
pm.dexopt.install=speed-profile
dalvik.vm.dex2oat-filter=speed
```

### Fix 5: Enable ro.debuggable for wrap property support (NEW)
In `device.mk` or `BoardConfig.mk`:
```
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += ro.debuggable=1
```
This allows `wrap.<package>` properties for future per-app LD_PRELOAD needs
without system-wide modules.

---

## TEST REQUEST (when phone is back, SAFE approach)

1. Boot phone WITHOUT `svc_timeout` Magisk module (remove in recovery):
   `rm -rf /data/adb/modules/svc_timeout/`

2. Boot phone WITHOUT `meow_stub` Magisk module (for clean test):
   `rm -rf /data/adb/modules/meow_stub/`

3. Ensure libMEOW stub is in place (from build-21 vendor image):
   `wc -c < /vendor/lib/egl/libMEOW_gift.so` should be 60 (stub)

4. Install original APK: `adb install /root/android/reveny-detector.apk`

5. Fix dex2oat CPU set: `resetprop dalvik.vm.dex2oat-cpu-set 0,1,2,3`

6. Compile app: `pm compile -m speed -f com.reveny.nativecheck`

7. Cold launch and observe:
   - `am start -n com.reveny.nativecheck/.ui.activity.MainActivity`
   - Wait 15 seconds
   - `pidof com.reveny.nativecheck` — should be ALIVE
   - `screencap /data/local/tmp/sc_final.png`
   - Check logcat: Toast shown, no signal 9, no timeout messages

8. If app stays alive: build-22 fixes sufficient.
   If app still dies: the kill is from an unfound system path.
   In that case, enable wrap: `setprop wrap.com.reveny.nativecheck "LD_PRELOAD=/system/lib/libkillblock.so"`
   and test again — this is app-specific LD_PRELOAD, NOT system-wide.

## LOGBOOK

### GitHub: MostafaAshry513/device_infinix_X657B
DETECTOR_DONE.md with complete offline analysis and build-22 fix plan.

### Mega: /X657B-build/
DETECTOR_DONE.md uploaded.
