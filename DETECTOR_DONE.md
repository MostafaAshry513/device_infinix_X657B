# DETECTOR FIX — com.reveny.nativecheck on X657B (build-20 → build-22)

## STATUS: Three ROM-side fixes deployed and validated

1. **libMEOW stub** ✅ — `applied 0 plugin`, stops GL/EGL injection. Persists across reboots.
2. **dex2oat CPU set fix + AOT** ✅ — ROM bug fixed (CPU set 0-7 on 4-core), `pm compile` works, odex mapped r-xp.
3. **Framework timeout patch** ✅ — services.jar + odex/vdex/art rebuilt via LineageOS build system. 
   PAUSE_TIMEOUT, LAUNCH_TICK, TOP_RESUMED_STATE_LOSS: 500→3000ms. Active via Magisk module.
   **Verified**: "Activity top resumed state loss timeout" and "Activity pause timeout" no longer appear in logs.

## Remaining: App receives SIGKILL at ~1.9s from unidentified source

With the timeout patch active, the ActivityManager timeout is eliminated (no timeout messages).
The app still dies with signal 9 (SIGKILL) at ~1.9s after start. The app shows a Toast with
results before dying. "Consumer closed input channel" indicates the app exits on its own.

**The SIGKILL is NOT from:**
- ActivityManager lifecycle timeout (eliminated by patch — no timeout messages)
- libMEOW injection (stub active — 0 plugins)
- DEX verification (AOT compilation — odex mapped r-xp)
- Self-kill via kill()/exit() in Java (no such calls found in smali)
- Native crash (no tombstone generated)

**The SIGKILL MAY be from:**
- `libreveny.so` native code calling `kill(getpid(), SIGKILL)` (LD_PRELOAD wrapper couldn't verify)
- App calling `finish()` after showing Toast (normal app behavior)
- ContentProvider or other system timeout

## Build-22 Source Changes (all ready)

| File | Change |
|------|--------|
| `frameworks/base/.../wm/ActivityRecord.java:384` | `PAUSE_TIMEOUT`: 500 → 3000 |
| `frameworks/base/.../wm/ActivityRecord.java:387` | `LAUNCH_TICK`: 500 → 3000 |
| `frameworks/base/.../wm/ActivityStackSupervisor.java:177` | `TOP_RESUMED_STATE_LOSS_TIMEOUT`: 500 → 3000 |
| `system.prop` | `dalvik.vm.dex2oat-cpu-set`: `0,1,2,3,4,5,6,7` → `0,1,2,3` |
| `proprietary/vendor/lib/egl/libMEOW_gift.so` | Replace with stub (84 bytes, orig backed up) |
| `device.mk` | `PRODUCT_DEXPREOPT_SPEED_APPS += com.reveny.nativecheck` |

## Deployed Live (build-20)

- Magisk module `meow_stub`: libMEOW_gift.so → 60-byte stub (post-fs-data bind mount)
- Magisk module `svc_timeout`: patched services.jar + odex/vdex/art (built from source)
- AOT: `pm compile -m speed` completed (odex in app dir)
- dex2oat CPU set fixed to 0,1,2,3

## LOGBOOK

### GitHub: MostafaAshry513/device_infinix_X657B
Final commit with all 3 fixes and build-22 source changes.

### Mega: /X657B-build/
DETECTOR_DONE.md uploaded.
