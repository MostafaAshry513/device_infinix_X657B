# DETECTOR FIX — com.reveny.nativecheck on X657B (build-20 → build-22)

## RESULT: THREE ROM-side fixes identified, two validated, one built and awaiting deployment

1. **libMEOW stub** ✅ — `applied 0 plugin`, stops GL/EGL injection
2. **AOT compilation fix** ✅ — found ROM bug (CPU set 0-7 on 4-core), `pm compile` now works, odex mapped with r-xp
3. **Framework timeout patch** 🔧 — patched services.jar built (PAUSE_TIMEOUT + TOP_RESUMED_STATE_LOSS: 500→3000ms), awaiting deployment

Toast with root-detection results confirmed multiple times. App displays UI (screenshot: 121KB PNG, 4780 colors). Post-display exit at ~460ms is from SYSTEM `libprocessgroup` kill (proven via LD_PRELOAD wrapper + thread dumps).

---

## FIX 1: Neutralize libMEOW_gift.so

**Root cause**: `libMEOW_gift.so` preloaded by zygote injects into every app. The `[CUSTOMIZE_BLACK]`
section in arc.ini is NOT recognized by the binary (confirmed via strings dump — only sections
`CUSTOMIZE`, `CUSTOMIZE_DRES`, `CUSTOMIZE_MRES` exist).

**Fix**: Replace `/vendor/lib/egl/libMEOW_gift.so` with a stub ELF (84 bytes).
**Build-22**: Source file replaced in `proprietary/vendor/lib/egl/libMEOW_gift.so` (orig backed up).

## FIX 2: AOT-compile the app (dex2oat fix)

**Root cause**: `pm compile` always failed because `dalvik.vm.dex2oat-cpu-set=0,1,2,3,4,5,6,7`
specified 8 CPUs but the MT6761 only has 4. dex2oat aborted: `Invalid cpu "d"`.

**Fix**: `resetprop dalvik.vm.dex2oat-cpu-set 0,1,2,3` then `pm compile -m speed` → Success.
Odex+vdex properly generated and mapped with r-xp in the app process.

**Build-22**: Fix `dalvik.vm.dex2oat-cpu-set` in `system.prop` to `0,1,2,3`.

## FIX 3: Increase activity lifecycle timeouts (services.jar patch)

**Root cause**: Even with AOT (no DEX verification overhead), the app's Compose UI init +
native library loading on the main thread triggers the 500ms activity pause timeout.
The system kills the process via `libprocessgroup`.

**Fix**: Patched two constants in `services.jar`:
- `ActivityRecord.PAUSE_TIMEOUT`: 500 → 3000ms
- `ActivityStackSupervisor.TOP_RESUMED_STATE_LOSS_TIMEOUT`: 500 → 3000ms

**Method**: Decompiled services.jar with apktool, patched smali constants, rebuilt.
Patched jar at `/tmp/services_patched.jar` (12MB), verified the constants changed.

**Build-22**: Apply the same source patch in:
- `frameworks/base/services/core/java/com/android/server/wm/ActivityRecord.java:384`
- `frameworks/base/services/core/java/com/android/server/wm/ActivityStackSupervisor.java:177`

---

## SIGKILL SOURCE: SYSTEM (ActivityManager), proven definitively

1. **LD_PRELOAD wrapper**: Intercepts kill()/exit()/exit_group() — no self-kill calls captured
2. **Thread dumps (SIGQUIT)**: Main thread in UI rendering (`ViewRootImpl.performTraversals`) or Compose init, NOT in kill/exit
3. **Logcat sequence**: `libprocessgroup: Successfully killed process cgroup` → system kill
4. **No tombstones**: SIGKILL doesn't produce native crash tombstones
5. **Toast survives process death**: system_server displays Toast after app process is killed

---

## BUILD-22 TREE CHANGES

| File | Change |
|------|--------|
| `proprietary/vendor/lib/egl/libMEOW_gift.so` | Replace with 84-byte stub ELF |
| `system.prop` or `build.prop` | Fix `dalvik.vm.dex2oat-cpu-set` to `0,1,2,3` |
| `device.mk` | Add `PRODUCT_DEXPREOPT_SPEED_APPS += com.reveny.nativecheck` |
| `frameworks/base/.../wm/ActivityRecord.java:384` | Change `PAUSE_TIMEOUT` from 500 to 3000 |
| `frameworks/base/.../wm/ActivityStackSupervisor.java:177` | Change `TOP_RESUMED_STATE_LOSS_TIMEOUT` from 500 to 3000 |
| `proprietary/vendor/etc/arc.ini` | Remove non-functional `[CUSTOMIZE_BLACK]` section |

## DEPLOYMENT STATUS (live build-20)

- ✅ libMEOW stub active via Magisk module (persists across reboots)
- ✅ AOT compilation completed (`pm compile` fixed CPU set, odex installed)
- 🔧 Patched services.jar at `/tmp/services_patched.jar` — awaiting tunnel restoration to deploy

## LOGBOOK

### GitHub: MostafaAshry513/device_infinix_X657B
Commit with three ROM-side fixes and build-22 plan.

### Mega: /X657B-build/
DETECTOR_DONE.md uploaded.
