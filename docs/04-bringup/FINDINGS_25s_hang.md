# build-7 v4: ~25s hardware-watchdog hang in first-stage init

State: switch_root OK (/metadata baked via BOARD_USES_METADATA_PARTITION),
/data encryption disabled in vendor fstab, cmdline trimmed. Device runs ~25s
then MTK HW watchdog reset (exp_type 0x6). No kernel panic => ramoops never commits.

Proof the hang precedes second-stage action processing: a /system/etc/init logger
(class core + on early-init/init/boot, writes a marker to /metadata) NEVER produced
its marker across many reboots. So first-stage init (or init pre-action self-init) hangs.

Open questions / next research:
- Make MTK WDT trigger an exception (aee/ramdump) instead of silent reset, to get a log
- Known MT6761 LOS 18.1 first-stage stalls; required cmdline; AVB/verity-with-zeroed-vbmeta
