# X657B LineageOS 18.1 — Project Notes

Everything needed to understand, rebuild, flash, and debug this ROM. Folders are
numbered in reading order; start at the top and work down.

## At a glance

- **Device:** Infinix Smart 5 (X657B), MediaTek MT6761, 32-bit ARM, Android 11 Go,
  non-A/B with dynamic partitions.
- **Last booted build:** build-20 — release-keys, stock `vendor`/`product`, stock boot
  (`57e6…`), vbmeta flags-3, flattened APEX, f2fs `/data`, SELinux enforcing.
- **Latest work:** `com.reveny.nativecheck` detector — build-22 fix plan.
- **Golden rule:** never break the working recipe (stock boot, vbmeta flags-3,
  flattened APEX, f2fs `/data`, enforcing SELinux).

## Tree

```text
docs/
├── README.md                          ← you are here
├── 01-overview/
│   ├── PROJECT_REFERENCE.md           ← master source of truth — START HERE
│   ├── AGENT_HANDOFF.md               ← resume brief: state, phone access, tools, rules
│   └── TEAM_TESTING_PLAN.md           ← test/polish checklist + adb-over-tunnel commands
├── 02-device/
│   └── SPECS.md                       ← hardware specs, each value cited to stock firmware
├── 03-build-and-flash/
│   ├── WORKING_BUILD_RECIPE.md        ← proven source tree + build commands
│   ├── INSTALL_METHOD.md              ← verified build-20 install method + recovery
│   └── FLASH_build9.md                ← earlier build-9 flash guide (historical)
├── 04-bringup/
│   ├── PROGRESS.md                    ← boot bring-up timeline and root causes
│   ├── RESUME_TOMORROW.md             ← paused switch_root debugging point
│   ├── FINDINGS_25s_hang.md
│   ├── FINDINGS_build9_exit127.md
│   ├── EXPERT_QUESTION_build9.md
│   └── ANSWERS_TO_EXPERT_build9.md
├── 05-detector/
│   ├── DETECTOR_DONE.md               ← reveny detector analysis + build-22 plan
│   └── DETECTOR_SOLVED                ← short status: app opens and shows Toast
└── 06-logbook/
    ├── BUILD_FIXES.md                 ← full chronological build/debug log (LIVE state at end)
    ├── BUILD-14-OTG-RECOVERY.md       ← OTG + TWRP survival
    ├── FINDINGS_apex_selinux.md       ← APEX/SELinux root cause
    └── STABLE_BUILD_AND_DEBUG.md      ← stable user build + on-device debugging
```

## Fast paths

| If you want to… | Read |
|---|---|
| Understand the project | Root [`README.md`](../README.md) → [`PROJECT_REFERENCE.md`](01-overview/PROJECT_REFERENCE.md) |
| Resume work | [`AGENT_HANDOFF.md`](01-overview/AGENT_HANDOFF.md), then the last entries of [`BUILD_FIXES.md`](06-logbook/BUILD_FIXES.md) |
| Build the ROM | [`WORKING_BUILD_RECIPE.md`](03-build-and-flash/WORKING_BUILD_RECIPE.md) → [`INSTALL_METHOD.md`](03-build-and-flash/INSTALL_METHOD.md) |
| Flash / recover the phone | [`INSTALL_METHOD.md`](03-build-and-flash/INSTALL_METHOD.md) |
| Debug a boot failure | [`04-bringup/`](04-bringup/) + [`FINDINGS_apex_selinux.md`](06-logbook/FINDINGS_apex_selinux.md) |
| Work on the root detector | [`DETECTOR_DONE.md`](05-detector/DETECTOR_DONE.md) |
| See the full history | [`BUILD_FIXES.md`](06-logbook/BUILD_FIXES.md) |

## Status history (newest first)

1. **build-22 (in progress):** detector fix plan — libMEOW stub, AOT precompile,
   dex2oat CPU set `0-3`, framework timeouts 500→3000 ms.
2. **build-20 (booted):** release-keys, Lawnchair as system launcher, GApps,
   CameraGo, raw-super installer. See [`INSTALL_METHOD.md`](03-build-and-flash/INSTALL_METHOD.md).
3. **build-14:** OTG + TWRP survival + normal (non-Go) memory config.
4. **build-13:** first full boot to the launcher (flattened APEX + f2fs `/data`).

## Note on sources

The live build tree and phone-access scripts live on the build server
(`/root/android/lineage`), not in this repo. This repo holds the device tree plus
the notes above. Historical notes are preserved as written — when documents
disagree, trust the newest entry in [`BUILD_FIXES.md`](06-logbook/BUILD_FIXES.md).
