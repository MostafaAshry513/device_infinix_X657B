# Answers to expert + new data (X657B build-9 exit-127)

## Direct answers to what you asked for

### `readelf -l` interpreter
```
[Requesting program interpreter: /system/bin/bootstrap/linker]
```
32-bit. Bootstrap linker is `ELF 32-bit ARM, static-pie`. No 32/64 mismatch.

### init is Lineage-built (NOT stock)
`/system/bin/init` = 785112 bytes, built 2026-05-30 04:46, ELF 32-bit ARM,
dynamically linked. From our LOS 18.1 build.

### `readelf -d /system/bin/init` (NEEDED)
libbacktrace libbase libbootloader_message libcutils libext4_utils libfs_mgr libgsi
libhidl-gen-utils libkeyutils liblog liblogwrap liblp libprocessgroup
libprocessgroup_setup libselinux libutils libc++ libc libm libdl

### FULL recursive dependency closure (this is the key new test)
Computed the complete transitive closure of /system/bin/init against the libs that
actually exist at second-stage entry:
- search = /system/lib + /system/lib/bootstrap (APEXes NOT mounted yet)
- **37 transitive libs, ALL 37 resolve. Zero missing. No APEX-only gap.**
- libc.so/libdl.so/libm.so correctly resolve to /system/lib/bootstrap/ (the apex-shadow set);
  /system/lib/bootstrap/ contains exactly: libc.so libdl.so libdl_android.so libm.so.
- libc++, liblog, libselinux, libprocessgroup(+libcgrouprc transitively), etc. all present in /system/lib.

### Panic shape (clean exit, not abort)
```
Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
... do_exit -> sys_exit_group ...
```
=> exit(127), confirmed NOT SIGABRT(6).

### On-device chroot reproduction (TWRP)
`chroot <mounted system> /system/bin/init selinux_setup` (with /dev /proc /sys + vendor/
product/system_ext mounted) **links successfully and reaches**:
```
init: Loading SELinux policy
init: Compiling SELinux policy
secilc ... (ran 666 ms)
init: starting service 'gatekeeperd' ...
```
So with these exact binaries+libs, the bootstrap linker resolves everything AND symbol
resolution succeeds AND init runs into second_stage. (The later chroot errors — "Failed to
open file_contexts", missing /sys/fs/selinux/null — are TWRP-chroot artifacts.)

## So: the missing-dependency hypothesis appears RULED OUT
- complete closure (37/37),
- chroot links + runs the real binary,
- exit is clean 127 (linker-style) but no lib is missing and symbols resolve in chroot.

## New ambiguity worth your eyes: the 1-second gap
ramoops timestamps: panic message at **1.413s**, but the do_exit backtrace at **2.430s**
(~1s later). On a normal single panic these are microseconds apart. Possibilities:
1. init actually RAN ~1s (≈ the 666ms secilc compile + setup) then exited — meaning it may
   HAVE reached "Loading SELinux policy" but those lines were lost (ring-buffer wrap / a
   different CPU buffer / second-stage re-init of kmsg logging dropped them).
2. The pstore ring spans TWO bootloop cycles and we're conflating them.
ramoops.console_size = 0x40000 (256KB); captured file = 227KB ending at panic.

## Refined questions
1. Given the closure is complete and chroot links+runs, what real-early-boot-only condition
   makes the SAME bootstrap linker exit 127? (mount-namespace / propagation after switch_root?
   a bootstrap-namespace ld config difference vs chroot? /dev or /proc not carried across
   switch_root so an early open() fails -> exit?)
2. Could second-stage init be reaching SetupSelinux and dying in the boot-time secilc compile
   in a way that yields 127 (e.g. the compile child exec failing -> 127) rather than 6 — and
   the "Loading SELinux policy" line being lost from ramoops? If so, a matching
   precompiled_sepolicy (skip boot compile) WOULD be the fix after all.
3. Any way to force the linker to emit diagnostics to kmsg this early without a usable cmdline
   (debug.ld.* props won't exist yet; LD_DEBUG needs env we can't set pre-init)?

## How to reproduce our checks
Device tree + all docs: GitHub MostafaAshry513/device_infinix_X657B,
Mega /X657B-build/roms/build-9-los-boot/ (ramoops_build9.txt, FINDINGS_build9_exit127.md).
