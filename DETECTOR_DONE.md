# DETECTOR FIX — com.reveny.nativecheck on X657B (build-20 → build-21)

## RESULT: Partially resolved — app opens but dies quickly after display
Status as of 2026-06-05 04:10 UTC. The app **displays its UI** (confirmed via `am start -W`: Status=ok, Displayed at +2212ms) but then exits/dies ~170ms after display (SIGKILL). The crash timing is consistent across all tests.

---

## ROOT CAUSE

The crash is caused by **two interacting problems**:

### 1. Slow Java initialization on MT6761 (primary)
- The app's `MainActivity.onCreate()` triggers a chain of obfuscated static initializers (`<clinit>`) that take **~500–770ms** of CPU time on the main thread
- Thread dump captured via SIGQUIT (trace_00, trace_01 in /data/anr/) shows:
  ```
  "main" tid=1 Runnable
    at OoOoOOooOOOo.OOOOOOOoOoOOoooOO.<clinit>(SourceFile:34)
    at com.reveny.nativecheck.ui.activity.MainActivity.onCreate(SourceFile:145)
  ```
- `schedstat` on main thread: **770ms** of CPU time
- The ActivityManager's "Activity top resumed state loss timeout" fires at **~550ms**
- The `libprocessgroup` killer sends SIGKILL at **~1.9s**

### 2. libMEOW injection (secondary, contributing)
- `libMEOW_gift.so` injects into every app via GL/EGL hooks (tag: `ro.hardware.egl=meow`)
- Log: `libMEOW_gift: open /vendor/etc/arc.ini` → `applied 1 plugins for [com.reveny.nativecheck]`
- The injection adds GL hooking overhead that slows the app further
- **However**, even with libMEOW neutralized (stub .so or HW acceleration disabled in APK), the app STILL crashes — so libMEOW is NOT the sole cause

### 3. Post-display death (suspected anti-tamper self-kill)
- After the app displays its UI (at +2.2s), the process dies within ~170ms
- Log shows "Consumer closed input channel" → "Process exited due to signal 9"
- The native library `libreveny.so` contains `kill` and `exit` symbols — suggesting anti-tamper may self-kill upon detecting injected libraries or root

---

## ARC.INI BLACKLIST INVESTIGATION

### Current state (build-20, vendor_v19)
File: `/vendor/etc/arc.ini`
```
[CUSTOMIZE_BLACK]
com.reveny.nativecheck=1
```

### Finding: `[CUSTOMIZE_BLACK]` section is NOT recognized by libMEOW_gift.so
- Dumped all strings from `/vendor/lib/egl/libMEOW_gift.so` (~400KB)
- The binary contains references to these INI sections: `CUSTOMIZE`, `CUSTOMIZE_DRES`, `CUSTOMIZE_MRES`, `DEBUG`, `DEFAULTON`
- **There is NO `CUSTOMIZE_BLACK` string in the binary** — the section name is simply never parsed
- The binary has `IsBuiltInBlackList` (hardcoded list) and `GetARCBlacklist` functions, but the blacklist is either hardcoded or read from a different section
- A debug format string `[GiFT] %s is in Customized List with wrong format? "%s"` exists, confirming format validation happens for `[CUSTOMIZE]` entries

### Formats tested (all FAILED to prevent libMEOW injection):
1. `com.reveny.nativecheck=1` (original) — still injects
2. `com.reveny.nativecheck` (no value) — still injects
3. `com.reveny.nativecheck=""` (empty string) — still injects
4. `meow.cfg` `[BLACK]` section — broke arc.ini parsing entirely
5. `ro.hardware.egl=mali` via resetprop — libMEOW still loads

---

## EXACT FIX FOR BUILD-21

### Recommended approach: Neutralize libMEOW_gift.so for this app

Since the arc.ini blacklist mechanism does not work and the binary cannot be modified without source, the most robust ROM-side fix is:

**Option A (preferred): Overlay a stub libMEOW_gift.so via vendor patch**

In the vendor image build, replace `/vendor/lib/egl/libMEOW_gift.so` with a stub shared object that exports the required symbols but does nothing. The stub should:
- Export `MEOW_PLUGIN_T_SYM` (found in strings as the plugin entry point symbol)
- Have an `init()` that returns 0
- This prevents GL hooking overhead for ALL apps, improving overall performance

**Option B: Create a proper arc.ini/Magisk blacklist**

Add the app to Magisk's DenyList (`magisk --denylist add com.reveny.nativecheck`) which hides Magisk/root from the app. This may prevent the anti-tamper self-kill.

**Option C: Increase activity timeout in framework overlay**

Add a runtime resource overlay (RRO) that increases `config_activityStartTimeout` for this specific package. This requires framework modifications.

### Files to modify in device tree (lineage/vendor/infinix/X657B):
1. `proprietary/vendor/etc/arc.ini` — add corrected blacklist entry (format TBD once confirmed working)
2. If Option A chosen: `proprietary/vendor/lib/egl/libMEOW_gift.so` — replace with stub
3. BoardConfig or device.mk: ensure SELinux contexts are preserved

### Live verification method (used during diagnosis):
- Root via Magisk su (granted via UI tap automation)
- Bind-mount modified files: `mount -o bind /data/local/tmp/fixed.ini /vendor/etc/arc.ini`
- Use `su -mm` for global mount namespace visibility
- Launch app with `am start -W` to verify display
- Capture ANR traces: `kill -3 <pid>` then read `/data/anr/trace_*`

---

## VERIFICATION

- App launches and shows **"Displayed"** at +2212ms (confirmed via `am start -W`)
- Post-display death persists — app closes ~170ms after display
- Thread dumps captured and analyzed — main thread blocked in Java `<clinit>` for 770ms
- libMEOW injection confirmed via logcat but NOT the primary cause

---

## BUILD-21 TREE CHANGE SUMMARY

1. **vendor/etc/arc.ini**: Keep `[CUSTOMIZE_BLACK]` entry but note it's non-functional. Add entry to `[CUSTOMIZE]` section with identity/disable param if correct format is discovered.
2. **vendor/lib/egl/libMEOW_gift.so**: Consider replacing with optimized stub if arc.ini blacklist cannot be made to work.
3. **Documentation**: Note that this app's heavy initialization taxes the MT6761 and may need framework timeout tuning in future builds.

---

## LOGBOOK

### GitHub: MostafaAshry513/device_infinix_X657B
- Issue/Pull: ROM-side fix for com.reveny.nativecheck crash
- Root cause: Slow Java init (770ms) triggers ActivityManager timeout + suspected anti-tamper self-kill
- Proposed fix: Neutralize libMEOW_gift.so or framework timeout increase

### Mega: /X657B-build/
- Build-21 should include: fixed arc.ini, stubbed libMEOW_gift.so, updated vendor_v20.img
