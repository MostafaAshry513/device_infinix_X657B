#!/bin/bash
set -e
OUT=/root/android/signed20
LPMAKE=/root/android/lineage/out/host/linux-x86/bin/lpmake
LPDUMP=/root/android/lineage/out/host/linux-x86/bin/lpdump
SIMG2IMG=/root/android/lineage/out/host/linux-x86/bin/simg2img
VENDOR=/root/android/raw/vendor_v19.img
SUPEROUT=/root/android/super_v20.img
TMP=/root/android/tmp_super; mkdir -p $TMP
roundup(){ echo $(( ($1 + 4095) / 4096 * 4096 )); }
unsparse(){ local n=$1 src=$OUT/$1.img dst=$TMP/$1.raw; file "$src"|grep -q sparse && { "$SIMG2IMG" "$src" "$dst"; echo "$dst"; } || echo "$src"; }
RSYS=$(unsparse system); RSE=$(unsparse system_ext); RPR=$(unsparse product)
SZ_SYS=$(roundup $(stat -c%s "$RSYS")); SZ_SE=$(roundup $(stat -c%s "$RSE")); SZ_PR=$(roundup $(stat -c%s "$RPR")); SZ_VEN=$(roundup $(stat -c%s "$VENDOR"))
TOTAL=$((SZ_SYS+SZ_SE+SZ_PR+SZ_VEN))
echo "RAW sizes: system=$SZ_SYS system_ext=$SZ_SE product=$SZ_PR vendor=$SZ_VEN total=$TOTAL (max 3435134976)"
[ $TOTAL -le 3435134976 ] || { echo "EXCEEDS GROUP MAX"; exit 1; }
"$LPMAKE" --metadata-size 65536 --metadata-slots 2 --device super:3439329280 --group main:3435134976 \
  --partition system:readonly:$SZ_SYS:main --image system="$RSYS" \
  --partition system_ext:readonly:$SZ_SE:main --image system_ext="$RSE" \
  --partition product:readonly:$SZ_PR:main --image product="$RPR" \
  --partition vendor:readonly:$SZ_VEN:main --image vendor="$VENDOR" \
  --sparse --output "$SUPEROUT"
rm -f $TMP/*.raw
echo "=== output ==="; ls -la "$SUPEROUT"
