# FINDINGS — the real root cause of the X657B crash-loop (2026-05-31)

## ONE-LINE ROOT CAUSE (high confidence)
The ROM boots **SELinux ENFORCING** (runtime `/sys/fs/selinux/enforce = 1`), our permissive-force
never takes effect, and under enforcing **apexd's mounts are denied** → `/apex` is never populated →
`/apex/com.android.runtime/bin/linker` missing → **every dynamically-linked service exits 127** → crash-loop → fastboot.

## HOW WE KNOW (on-device evidence, build-12)
- Instrumented init.rc to dump state right after `exec_start apexd-bootstrap` (init builtins only, since no
  binary can link). Result on `/metadata`:
  - **`dbg_enforce.txt = 1`** → SELinux ENFORCING at runtime.
  - (`dbg_mounts.txt` not written — init `copy` builtin can't read procfs `/proc/mounts` (size 0). Use a
    different capture next time.)
- `wrapinit.log`: `apexd-bootstrap` exits `code=1 status=0` (success) but the next dynamically-linked binary
  (`boringssl_self_test32`) dies `status=127`. So apexd "succeeds" yet `/apex/com.android.runtime` is not mounted.
- Same 127 symptom in BOTH flattened apex (build-10) and updatable apex (build-12) — so apex-mode was NEVER
  the cause. (build-12 = clean updatable apex: 21 real .apex files, ro.apex.updatable=true — verified.)
- Earlier "real-linker" test had shifted 127→status=1 (linker ran, libs missing) — consistent with /apex empty.

## WHY OUR PERMISSIVE-FORCE FAILS (mechanism, from init/selinux.cpp)
`SelinuxInitialize()`:
```
477  bool kernel_enforcing = (security_getenforce() == 1);
478  bool is_enforcing = IsEnforcing();          // returns TRUE
479  if (kernel_enforcing != is_enforcing)
480      security_setenforce(is_enforcing);      // <-- flips kernel to ENFORCING
486  WriteFile("/sys/fs/selinux/checkreqprot","0");
492  security_setenforce(0);                      // <-- our hack: DENIED (return val unchecked) once enforcing
```
`IsEnforcing()` returns true because `StatusFromCmdline()` defaults to `SELINUX_ENFORCING` (selinux.cpp:95)
and **MTK LK strips the boot.img cmdline**, so `androidboot.selinux=permissive` never arrives. Line 480 makes
the kernel enforcing; line 492's `setenforce(0)` is then itself an SELinux-gated op and is **silently denied**
(no return-value check). Net: enforcing stays on.

## THE FIX TO TRY FIRST (next session) — force GENUINE permissive
Minimal, correct one-liner in `/root/android/lineage/system/core/init/selinux.cpp`:
- Line 95: `EnforcingStatus status = SELINUX_ENFORCING;`  ->  `SELINUX_PERMISSIVE;`
  Then `IsEnforcing()` returns false -> init NEVER flips to enforcing (line 480 skipped) -> line 492
  `setenforce(0)` runs while still permitted -> runtime stays PERMISSIVE.
  (Keep line 492 as belt-and-suspenders. Requires ALLOW_PERMISSIVE_SELINUX, true on eng builds — confirm.)
- Alternative belt: also delete/skip the 477-484 block so we never call setenforce(1).

### Cheap test loop (no full rebuild, internet-friendly)
1. Edit selinux.cpp line 95 as above.
2. `mka init` (builds just the init binary, fast). The instrumented breadcrumb init stays.
3. Deploy ONLY the init binary (~2 MB): scp server->Mac, adb push, mount mapper/system rw,
   cp -> /system/bin/init, restorecon/chcon u:object_r:init_exec:s0, chmod 0755, sync.
4. Clear /metadata + pstore, reboot, bootwatch. Check `/sys/fs/selinux/enforce` dump = 0 and whether /apex
   populates (services stop 127ing). If it boots -> permissive was the wall.

## OPEN QUESTION the research must close (glm running)
Under enforcing, WHY is apexd denied when normal LOS devices boot enforcing fine? Leading theory:
**LOS system on STOCK Infinix vendor → sepolicy/version-mapping mismatch**, so the on-device policy denies
apexd's loop/bind/dm mounts (loop-device + /apex tmpfs labeling are partly vendor-owned). Permissive masks
this; the "proper" fix is to reconcile sepolicy (audit2allow from real AVC denials, or matched vendor).
Next session: capture actual AVC denials (enforcing boot) to see exactly what apexd is denied — e.g. add an
init service that copies the kernel audit ring, or read pstore after a forced panic, or boot permissive +
`dmesg | grep avc` once logd works.

## SECONDARY ISSUES NOTED (fix in the source tree too)
- `boringssl reboot_on_failure` removal was only ever done ON-PHONE (build-10). Fresh builds reintroduce it →
  fast reboot loops. Remove in the SOURCE init.rc / build (it's in bionic/boringssl init.rc or device overlay).
- Device still reboots to fastboot even with reboot_on_failure stripped → a HW watchdog / KE fires on the
  failed boot. Expected once services crash-loop; should disappear once boot proceeds.

## QUICK-RESUME POINTER
Phone in TWRP. adb/fastboot via Mac reverse tunnel (server:2222 -> Mac:22, user brucewayne,
/usr/local/bin/{adb,fastboot}); wrappers ~/bin/padb, ~/bin/bootwatch. Built image:
/root/android/flash_build9/system_v12_fit.img (708MB sparse, fits the 924MiB system logical partition,
md5 1ec0834cb6b5f754825df906d573a8fe) — already ON the phone with the instrumented init.rc.
boot=working_ref/boot.emmc.win (57e6), vbmeta flags-3. glm-5.1 research -> /root/android/flash_build9/glm_research.txt.

---
# UPDATE 2026-05-31 (later): THE KERNEL IS ENFORCE-LOCKED — runtime permissive is IMPOSSIBLE
## Decisive evidence (extract-ikconfig on working_ref/boot.emmc.win = the Android boot kernel)
```
CONFIG_SECURITY_SELINUX=y
# CONFIG_SECURITY_SELINUX_BOOTPARAM is not set    -> no enforcing=0 / androidboot.selinux cmdline override
# CONFIG_SECURITY_SELINUX_DISABLE is not set       -> cannot disable selinux at runtime
# CONFIG_SECURITY_SELINUX_DEVELOP is not set        -> ENFORCE-LOCKED: always enforcing once policy loaded
CONFIG_SECURITY_SELINUX_CHECKREQPROT_VALUE=0
```
## What this means
- With DEVELOP=n, the kernel ignores/denies security_setenforce(0). SELinux is ALWAYS enforcing after the
  policy loads. Every "force permissive" attempt this project made (security_setenforce(0) in init) was a
  silent no-op -> we were ALWAYS enforcing. That is the deepest root cause of the apexd-denied / 127 chain.
- Proof from the failed test: setting IsEnforcing()->false made init call security_setenforce(0) at
  selinux.cpp:480; on this kernel that fails -> init aborts in SelinuxInitialize -> "Attempted to kill init!"
  kernel panic (wrapinit stops at "before SelinuxInitialize"; ramoops committed a fresh panic).
- The old (enforcing) init "worked better" only because its setenforce(0) was at line 492 with the return
  value UNCHECKED, so the failure was swallowed and init limped on to second stage (then 127 at services).
## CONCLUSION: cannot boot permissive on this device without a kernel change. Two real paths:
### PATH A (proper, what GSIs do): make the ENFORCING policy CORRECT
GSIs boot enforcing on this same locked kernel -> a correct policy works. Ours is broken because LOS SYSTEM
runs on STOCK Infinix VENDOR (sepolicy/mapping mismatch) so apexd's loop/bind/dm mounts get DENIED.
- Next: capture the actual AVC denials. Boot with the ENFORCING (old) instrumented init so it reaches the
  service phase; the locked kernel logs "avc: denied ..." to the kernel audit ring -> read from
  /sys/fs/pstore/console-ramoops-0 (on the panic) or /dev/kmsg. Feed denials -> add allow rules to device
  sepolicy (or use the MATCHED vendor (noophyy) instead of stock) -> rebuild -> repeat until /apex mounts.
### PATH B (fast hack): ship a FULLY-PERMISSIVE POLICY (works even on enforce-locked kernels)
A policy can mark every domain as a "permissive domain"; the kernel still "enforces" but permissive domains
only log AVCs. Achieve by patching the loaded/binary policy with magiskpolicy ("permissive *") or by adding
typepermissive for all domains in the CILs. Complication: this device uses SPLIT policy compiled on-device
by init from CILs (plat_sepolicy.cil + mapping + vendor) -> need to patch the CILs or the precompiled_sepolicy
that init loads. Magisk IS present in the boot ramdisk (/debug_ramdisk) -> magiskpolicy is available.
## IMMEDIATE next action
Revert the permissive init (it panics). Rebuild the ENFORCING instrumented init, redeploy, boot to the
service phase, and CAPTURE AVC DENIALS from ramoops -> that tells us exactly what to allow (Path A) and
whether stock-vendor mismatch is the culprit.
