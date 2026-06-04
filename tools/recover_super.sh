#!/system/bin/sh
set -e
SUPER=/dev/block/by-name/super
UD=/dev/block/by-name/userdata
MD=/dev/block/by-name/metadata
EXPECT_256=3921407e4d69b6a7a121f0480f830a13
echo "=== format userdata scratch $(date) ==="
umount /scratch 2>/dev/null || true
mke2fs -F -q -t ext4 "$UD" >/dev/null 2>&1
mkdir -p /scratch
mount -t ext4 "$UD" /scratch
echo "scratch: $(df -h /scratch 2>/dev/null | tail -1)"
echo "=== simg2img: expand on-partition sparse -> /scratch/raw.img ==="
simg2img "$SUPER" /scratch/raw.img
SZ=$(stat -c%s /scratch/raw.img 2>/dev/null)
echo "raw.img size=$SZ (expect 3439329280); first4=$(dd if=/scratch/raw.img bs=4 count=1 2>/dev/null | od -An -tx1)"
M256=$(dd if=/scratch/raw.img bs=1M count=256 2>/dev/null | md5sum | awk '{print $1}')
echo "raw first256=$M256 (expect $EXPECT_256)"
[ "$M256" = "$EXPECT_256" ] || { echo "FATAL raw mismatch"; exit 1; }
echo "=== write raw super -> super partition ==="
dd if=/scratch/raw.img of="$SUPER" bs=8M
sync
SM=$(dd if="$SUPER" bs=1M count=256 2>/dev/null | md5sum | awk '{print $1}')
echo "super first256 now=$SM (expect $EXPECT_256)"
[ "$SM" = "$EXPECT_256" ] || { echo "FATAL super verify mismatch"; exit 1; }
echo "super first4 now: $(dd if=$SUPER bs=4 count=1 2>/dev/null | od -An -tx1)"
echo "=== cleanup: unmount + zero userdata/metadata (clean reformat on boot) ==="
umount /scratch
dd if=/dev/zero of="$UD" bs=1M count=100 2>/dev/null
dd if=/dev/zero of="$MD" bs=1M count=8 2>/dev/null
sync
echo "=== RECOVERY OK $(date) ==="
