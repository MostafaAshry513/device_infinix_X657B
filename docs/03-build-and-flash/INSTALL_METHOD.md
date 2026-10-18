# X657B build-20 — Install Method (WORKING, verified booted 2026-06-04)

## Flashable zip = `X657B-build20-installer.zip`
- md5 (RAW-super, correct): `8d1883f1dafe54c7cbcd4b83582fb34e` (3.3G)
- Contents: META-INF/update-binary (shell), boot.img (stock 57e6), vbmeta{,_system,_vendor}.img,
  super.part.00..12 (256MB **RAW** chunks of super_v20_raw.img).
- super_v20 = system20+system_ext20+product20 + **vendor_v19 (reveny detector arc.ini fix)**.

## CRITICAL lesson (this is what caused the build-20 bootloop the first time)
- `lpmake --sparse` outputs a **SPARSE** super (`magic 3aff26ed`). The shell installer `dd`s chunks RAW.
- A sparse image dd'd raw = invalid super metadata → dynamic partitions don't mount → **BOOTLOOP**.
- **MUST** `simg2img super_vNN.img super_vNN_raw.img` and split the **RAW** (starts `00000000`,
  total = full 3439329280) before chunking. (build20_installer.sh now does this.)

## Flash procedure (TWRP, via adb)
1. Push zip to phone storage OR keep it for sideload. (We pushed to /sdcard.)
2. `adb reboot recovery` → TWRP.
3. Run the update-binary directly (keep /data mounted so on-storage zip stays readable):
   extract META-INF/.../update-binary, `sed 's#/mnt/system /data#/mnt/system#'` (drop /data from umount),
   then `sh update-binary 3 1 /sdcard/build20.zip`.
   (NOTE: ui_print writes to /proc/self/fd/$OUTFD fail over an ssh pipe — cosmetic only; dd flashing proceeds.)
4. update-binary flashes: boot, vbmeta(s), super (chunked `unzip -p | dd`), then **zeroes userdata+metadata** (clean wipe).
5. `adb reboot`. First boot formats /data (~3-5 min). USB-debugging is OFF after wipe → user re-enables.

## On-device super recovery (if a sparse super was flashed by mistake — NO re-transfer needed)
The partition holds the valid sparse super at its start. In TWRP:
1. `mke2fs -F -q -t ext4 /dev/block/by-name/userdata; mount -t ext4 ... /scratch`
2. `simg2img /dev/block/by-name/super /scratch/raw.img`  (expands on-partition sparse → raw)
3. verify raw.img md5 == server `super_v20_raw.img` (full `4ce8e593...`, first256 `3921407e...`)
4. `dd if=/scratch/raw.img of=/dev/block/by-name/super bs=8M`
5. `umount /scratch; dd if=/dev/zero of=.../userdata bs=1M count=100; dd .../metadata count=8; sync`
6. reboot.

## Boot recipe (unchanged): stock boot 57e6, vbmeta flags-3 (AVB off), zeroed userdata/metadata → f2fs reformat.
