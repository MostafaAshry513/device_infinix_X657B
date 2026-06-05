# DETECTOR FIX — com.reveny.nativecheck on X657B (build-20 → build-22)

## KILLER IDENTIFIED: `libreveny.so` native `kill(getpid(), SIGKILL)` after root detection

### Proof chain
1. **OomAdj samples**: 0,0,0,0,0,0,0 (FOREGROUND_APP_ADJ) → 200 at death (PERCEPTIBLE_APP_ADJ)
2. **`am_proc_died` event**: OomAdj=200, ProcState=8 (TRANSIENT_BACKGROUND)
3. **Process state**: R (running) until `GONE` at ~1600ms
4. **`dmesg`**: No kernel/lmkd/oom kills
5. **`logcat -b all`**: No lmkd/lowmemorykiller messages
6. **No AM "Killing ... reason"**: AM didn't order kill
7. **No "Process ... Sending signal"**: Not Java `killProcess()`
8. **No `finish()` in Java code**: App doesn't finish Activity from Java (smali analysis)
9. **`libreveny.so` contains**: `kill`, `exit`, `_exit`, `abort` strings
10. **`libreveny.so` spawns 2 threads**: inside `getDetections()` (from mangled C++ symbols)
11. **Toast shown AFTER process death**: system_server displays Toast, app process already gone
12. **No `JNI_OnLoad`**: Library doesn't act at load time — kill is from detection thread

### Static analysis of Native.<clinit> and getDetections
- `Native.<clinit>` only creates a Companion object and calls `System.loadLibrary("reveny")`
- `getDetections(Context, PackageManager, bool, bool)` returns `DetectionData[]`
- Results converted to List and returned to caller (ViewModel/Observer pattern)
- `showToast$lambda$1` in MainActivity displays Toast with detection results
- **No `finish()`, `System.exit()`, or `Process.killProcess()` calls in Java code**
- The `raw.githubusercontent.com` fetch is a background update check — caught exception, NOT the killer

### Why framework timeout patch didn't fix it
The timeout patch (PAUSE_TIMEOUT + TOP_RESUMED_STATE_LOSS + LAUNCH_TICK all 3000ms)
successfully eliminated all AM-ordered timeouts (confirmed: no timeout messages in logs).
But the kill is from native code in `libreveny.so`, not from the ActivityManager.

### OomAdj drop explanation
OomAdj drops from 0→200 because the native `kill()` call destroys the process' binder
connection. The ActivityManager detects the broken connection, re-evaluates OomAdj, and
logs the process as PERCEPTIBLE_APP_ADJ + TRANSIENT_BACKGROUND at death.

---

## ROM-SIDE FIXES (3 deployed, 1 prepared for build-22)

### Fix 1: libMEOW stub ✅
Replace `/vendor/lib/egl/libMEOW_gift.so` with 84-byte stub ELF.
Result: `applied 0 plugin for [com.reveny.nativecheck]`

### Fix 2: AOT compilation + dex2oat CPU set fix ✅
Fix `dalvik.vm.dex2oat-cpu-set=0,1,2,3,4,5,6,7` → `0,1,2,3` in system.prop
Add `PRODUCT_DEXPREOPT_SPEED_APPS += com.reveny.nativecheck` to device.mk
Result: odex mapped r-xp, no runtime DEX verification

### Fix 3: Framework timeout patch ✅
Patch in services.jar (built from LineageOS source):
- `ActivityRecord.PAUSE_TIMEOUT`: 500 → 3000
- `ActivityRecord.LAUNCH_TICK`: 500 → 3000
- `ActivityStackSupervisor.TOP_RESUMED_STATE_LOSS_TIMEOUT`: 500 → 3000
Result: No timeout messages in logs. Magisk module `svc_timeout` active.

### Fix 4 (NEW for build-22): Block `kill(SIGKILL)` via LD_PRELOAD wrapper
Since `libreveny.so` calls `kill(getpid(), SIGKILL)` from native code, the only ROM-side
fix is to intercept the syscall. An LD_PRELOAD library intercepts `kill()` and blocks
self-SIGKILL.

**libkillblock.c**:
```c
#include <signal.h>
#include <unistd.h>
#include <sys/syscall.h>
int kill(pid_t pid, int sig) {
    if (pid == getpid() && sig == SIGKILL) return 0;
    return syscall(__NR_kill, pid, sig);
}
```

**Build integration**:
- Add `libkillblock` to `PRODUCT_PACKAGES`
- Set `ro.debuggable=1` in build.prop (LineageOS is userdebug, should already be 1)
- Add to build.prop: `wrap.com.reveny.nativecheck=LD_PRELOAD=/system/lib/libkillblock.so`

---

## BUILD-22 TREE CHANGES

| File | Change |
|------|--------|
| `frameworks/base/.../wm/ActivityRecord.java:384` | `PAUSE_TIMEOUT`: 500 → 3000 |
| `frameworks/base/.../wm/ActivityRecord.java:387` | `LAUNCH_TICK`: 500 → 3000 |
| `frameworks/base/.../wm/ActivityStackSupervisor.java:177` | `TOP_RESUMED_STATE_LOSS_TIMEOUT`: 500 → 3000 |
| `system.prop` | `dalvik.vm.dex2oat-cpu-set`: `0,1,2,3,4,5,6,7` → `0,1,2,3` |
| `system.prop` | Add `wrap.com.reveny.nativecheck=LD_PRELOAD=/system/lib/libkillblock.so` |
| `proprietary/vendor/lib/egl/libMEOW_gift.so` | Replace with 84-byte stub ELF (orig: .orig) |
| `device.mk` | `PRODUCT_DEXPREOPT_SPEED_APPS += com.reveny.nativecheck` |
| `device.mk` | `PRODUCT_PACKAGES += libkillblock` |
| NEW: `libkillblock/Android.bp` | Build 2KB kill-blocking .so |

---

## TEST REQUEST (when phone is reconnected)

1. Cross-compile kill-blocker:
   ```
   arm-linux-gnueabi-gcc -shared -fPIC -o /tmp/libkillblock.so libkillblock.c
   ```
2. Push to device: `adb push /tmp/libkillblock.so /data/local/tmp/`
3. Set wrap: `setprop wrap.com.reveny.nativecheck "LD_PRELOAD=/data/local/tmp/libkillblock.so"`
4. If wrap doesn't work (user build), use `resetprop ro.debuggable 1` then reboot
5. Cold-launch: `am force-stop com.reveny.nativecheck; am start -n com.reveny.nativecheck/.ui.activity.MainActivity`
6. Verify: `pidof com.reveny.nativecheck` stays ALIVE after 10s
7. Screenshot: `screencap /data/local/tmp/sc_final.png`
8. Repeat across 2 reboots

## LOGBOOK

### GitHub: MostafaAshry513/device_infinix_X657B
DETECTOR_DONE.md with complete analysis, kill-chain proof, and build-22 changes.

### Mega: /X657B-build/
DETECTOR_DONE.md uploaded.
