# BUILD-9 FLASH GUIDE — Infinix X657B (LineageOS 18.1)

**What's new in build-9:** we stop mixing a *stock* ramdisk with the *source* system.
This `boot.img` is the **fully LOS-built** one (LOS first-stage init + LOS ramdisk, with
the `check` flag removed from the first-stage fstab). That fixes the `switch_root` exit-127
(`exitcode=0x7f00`) crash, which was caused by the stock first-stage init failing to
re-exec the LOS `/system/bin/init`.

**super_v5 is UNCHANGED and already on the phone — do NOT re-push it (1.5 GB).**
We only flash `boot.img` (33 MB) + tiny vbmeta images.

## Files (in this folder)
- `boot.img`               — LOS-built boot (THE key change)
- `vbmeta.img`             — flags=3 (AVB verification disabled)
- `vbmeta_system.img`      — chained vbmeta (no-op while vbmeta flags=3)
- `vbmeta_vendor_zero.img` — 4 KB zeros for vbmeta_vendor

## Flash (phone in TWRP, ADB up)
```
adb push boot.img               /tmp/boot.img
adb push vbmeta.img             /tmp/vbmeta.img
adb push vbmeta_system.img      /tmp/vbmeta_system.img
adb push vbmeta_vendor_zero.img /tmp/vbmeta_vendor.img

adb shell 'dd if=/tmp/boot.img          of=/dev/block/by-name/boot          bs=4096'
adb shell 'dd if=/tmp/vbmeta.img        of=/dev/block/by-name/vbmeta         bs=4096'
adb shell 'dd if=/tmp/vbmeta_system.img of=/dev/block/by-name/vbmeta_system  bs=4096'
adb shell 'dd if=/tmp/vbmeta_vendor.img of=/dev/block/by-name/vbmeta_vendor  bs=4096'

adb shell twrp wipe cache
adb shell twrp wipe dalvik
adb reboot
```
DO NOT touch super, dtbo, preloader, lk, nvram, nvdata, protect*.

## What to expect / how we read the result
- If it boots further than ~1.4 s and reaches the LOS boot animation → switch_root passed. 🎉
- Either way, the on-phone logger `/etc/init/zz_blog.rc` (second-stage) should now run and
  write `/metadata/blog.txt`. After it bootloops/hangs, get back to TWRP and:
```
adb pull /metadata/blog.txt ./blog_build9.txt        # (or /tmp/blog.txt depending on logger)
```
  Send me `blog_build9.txt` — that shows exactly where second-stage init stops.
- If it still dies at ~1.4 s with no blog.txt, capture ramoops:
```
adb shell 'cat /sys/fs/pstore/console-ramoops-0' > ramoops_build9.txt   # only if it PANICs
```
