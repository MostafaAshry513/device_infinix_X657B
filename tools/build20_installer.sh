#!/bin/bash
set -e
cd /root/android
echo "[1/6] extract signed images from signed-img20.zip"
rm -rf signed20; mkdir -p signed20
unzip -o signed-img20.zip system.img system_ext.img product.img -d signed20 >/dev/null
ls -lh signed20/

echo "[2/6] assemble super_v20 (uses vendor_v19 = detector fix)"
bash assemble_super_v20.sh

echo "[2b] simg2img sparse->raw (REQUIRED: dd installer needs RAW super, not sparse)"
/root/android/lineage/out/host/linux-x86/bin/simg2img super_v20.img super_v20_raw.img
echo "[3/6] split RAW super_v20 into 256MB chunks"
rm -rf zipbuild20; mkdir -p zipbuild20
( cd zipbuild20 && split -b 268435456 -d -a 2 /root/android/super_v20_raw.img super.part. )
ls zipbuild20/

echo "[4/6] stage boot + vbmeta from proven build-18"
unzip -o X657B-build18-installer.zip boot.img vbmeta.img vbmeta_system.img vbmeta_vendor.img -d zipbuild20 >/dev/null

echo "[5/6] write META-INF installer logic (build-20)"
mkdir -p zipbuild20/META-INF/com/google/android
cat > zipbuild20/META-INF/com/google/android/update-binary <<'UB'
#!/sbin/sh
OUTFD=$2; ZIP=$3
ui_print(){ echo "ui_print $1" >> /proc/self/fd/$OUTFD; echo "ui_print" >> /proc/self/fd/$OUTFD; }
BD=/dev/block/bootdevice/by-name; [ -d "$BD" ] || BD=/dev/block/by-name
ui_print " "; ui_print "==============================="; ui_print "  Infinix X657B  -  build-20"
ui_print "  LineageOS 18.1 (release-keys)"; ui_print "  *** CLEAN install: WIPES DATA ***"; ui_print "==============================="
if [ ! -b "$BD/super" ] || [ ! -b "$BD/boot" ]; then ui_print "!! super/boot not found - abort"; exit 1; fi
for m in /system_root /system /vendor /product /system_ext /mnt/system /data; do umount "$m" 2>/dev/null; done
ui_print "- Flashing boot..."; unzip -p "$ZIP" boot.img | dd of="$BD/boot" bs=4M 2>/dev/null
ui_print "- Flashing vbmeta..."; unzip -p "$ZIP" vbmeta.img | dd of="$BD/vbmeta" bs=1M 2>/dev/null
[ -b "$BD/vbmeta_system" ] && unzip -p "$ZIP" vbmeta_system.img | dd of="$BD/vbmeta_system" bs=1M 2>/dev/null
[ -b "$BD/vbmeta_vendor" ] && unzip -p "$ZIP" vbmeta_vendor.img | dd of="$BD/vbmeta_vendor" bs=1M 2>/dev/null
ui_print "- Flashing super (chunked, ~5 min)..."
CHUNKS=$(unzip -l "$ZIP" 2>/dev/null | grep -oE 'super\.part\.[0-9]+' | sort -u)
( for c in $CHUNKS; do unzip -p "$ZIP" "$c"; done ) | dd of="$BD/super" bs=8M 2>/dev/null
ui_print "- Formatting data (clean install)..."
dd if=/dev/zero of="$BD/userdata" bs=1M count=100 2>/dev/null
[ -b "$BD/metadata" ] && dd if=/dev/zero of="$BD/metadata" bs=1M count=8 2>/dev/null
sync
ui_print " "; ui_print "*** DONE - data wiped, clean install ***"
ui_print "Reboot > System. First boot a few min."
ui_print "Pick Lawnchair as Home; set dark+teal+Profiles+icon pack in Settings."
exit 0
UB
printf 'dummy\n' > zipbuild20/META-INF/com/google/android/updater-script

echo "[6/6] package zip (stored, no compression)"
rm -f /root/android/X657B-build20-installer.zip
( cd zipbuild20 && zip -0 -r -X /root/android/X657B-build20-installer.zip \
    META-INF boot.img vbmeta.img vbmeta_system.img vbmeta_vendor.img super.part.* >/dev/null )
cd /root/android
md5sum X657B-build20-installer.zip | tee X657B-build20-installer.zip.md5
ls -lh X657B-build20-installer.zip
echo "INSTALLER20 DONE $(date)"
