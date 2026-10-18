# X657B LineageOS 18.1 — Project Notes

This folder is the project's memory: state, build/flash recipes, debugging history,
and current work. Follow the numbers below so you always know what to read next.

## At a glance

- **Device:** Infinix Smart 5 (X657B), MediaTek MT6761, 32-bit ARM, Android 11 Go,
  non-A/B with dynamic partitions.
- **Last booted build:** build-20 — release-keys, stock `vendor`/`product`, stock boot
  (`57e6…`), vbmeta flags-3, flattened APEX, f2fs `/data`, SELinux enforcing.
- **Latest work:** `com.reveny.nativecheck` detector — build-22 fix plan.
- **Golden rule:** never break the working recipe (stock boot, vbmeta flags-3,
  flattened APEX, f2fs `/data`, enforcing SELinux).

## Read in this order

### Phase 1 — Get oriented (read before doing anything)

| # | Document | Read when | What it gives you |
|---|---|---|---|
| **1** | [Root README](../README.md) | First time opening the repo | What the ROM is, device summary, build/flash quickstart |
| **2** | [PROJECT_REFERENCE.md](01-overview/PROJECT_REFERENCE.md) | Before changing anything | Master state, hard limits, proven recipe, pending tasks |
| **3** | [AGENT_HANDOFF.md](01-overview/AGENT_HANDOFF.md) | Taking over or resuming work | Resume point, phone access, tools, workflow rules |
| **4** | [TEAM_TESTING_PLAN.md](01-overview/TEAM_TESTING_PLAN.md) | Before testing/polishing | Current checklist and exact adb-over-tunnel commands |

### Phase 2 — Know the current state

| # | Document | Read when | What it gives you |
|---|---|---|---|
| **5** | [BUILD_FIXES.md](06-logbook/BUILD_FIXES.md) | **Every session — start at the end** | Full chronological log; the last ~5 entries are the live state and next step |
| **6** | [SPECS.md](02-device/SPECS.md) | When you need hardware or partition facts | Verified panel, touch, camera, modem, PMIC, partition data |

### Phase 3 — Build and flash

| # | Document | Read when | What it gives you |
|---|---|---|---|
| **7** | [WORKING_BUILD_RECIPE.md](03-build-and-flash/WORKING_BUILD_RECIPE.md) | Before building | Proven source tree, local manifest, build commands |
| **8** | [INSTALL_METHOD.md](03-build-and-flash/INSTALL_METHOD.md) | Before flashing or recovering | Verified build-20 installer, on-device super recovery |
| **9** | [FLASH_build9.md](03-build-and-flash/FLASH_build9.md) | Only for historical context | Earlier build-9 flash method — superseded by **#8** |

### Phase 4 — Debugging bring-up (only if boot fails or you need history)

| # | Document | Read when | What it gives you |
|---|---|---|---|
| **10** | [FINDINGS_apex_selinux.md](06-logbook/FINDINGS_apex_selinux.md) | `/apex` is empty or services exit 127 | The APEX/SELinux root cause and why permissive is impossible |
| **11** | [PROGRESS.md](04-bringup/PROGRESS.md) | You need the boot timeline | What was tried and fixed from build 1 to build 20 |
| **12** | [RESUME_TOMORROW.md](04-bringup/RESUME_TOMORROW.md) | Investigating the `switch_root` failure | Paused debug point, on-phone state, next steps |
| **13** | [FINDINGS_25s_hang.md](04-bringup/FINDINGS_25s_hang.md) | Early-init hang at ~25 s | The 25-second boot halt investigation |
| **14** | [FINDINGS_build9_exit127.md](04-bringup/FINDINGS_build9_exit127.md) | Second-stage `init` exits 127 | Build-9 exit-127 analysis and evidence |
| **15** | [EXPERT_QUESTION_build9.md](04-bringup/EXPERT_QUESTION_build9.md) | You need the expert question | The build-9 problem statement sent out for review |
| **16** | [ANSWERS_TO_EXPERT_build9.md](04-bringup/ANSWERS_TO_EXPERT_build9.md) | Same as **#15** | Answers, checks, and conclusions |

### Phase 5 — Root detector work

| # | Document | Read when | What it gives you |
|---|---|---|---|
| **17** | [DETECTOR_DONE.md](05-detector/DETECTOR_DONE.md) | Before touching the detector/vendor | Full kill analysis and the build-22 fix plan |
| **18** | [DETECTOR_SOLVED](05-detector/DETECTOR_SOLVED) | You only need the status | App opens and shows the result Toast; remaining SIGKILL noted |

### Phase 6 — Historical logbook (read for context, not first)

| # | Document | Read when | What it gives you |
|---|---|---|---|
| **19** | [STABLE_BUILD_AND_DEBUG.md](06-logbook/STABLE_BUILD_AND_DEBUG.md) | You need build-14/stable context | Stable user build, Lawnchair, network/Play Integrity/GCam debugging |
| **20** | [BUILD-14-OTG-RECOVERY.md](06-logbook/BUILD-14-OTG-RECOVERY.md) | You need OTG/TWRP context | OTG enablement and TWRP-survival fixes |

> **Short path:** if you only read four things, read **#1 → #2 → #5 (last entries) → #7**.

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
    ├── FINDINGS_apex_selinux.md       ← APEX/SELinux root cause
    ├── STABLE_BUILD_AND_DEBUG.md      ← stable user build + on-device debugging
    └── BUILD-14-OTG-RECOVERY.md       ← OTG + TWRP survival
```

## Find a doc by goal

| If you want to… | Go to |
|---|---|
| Understand the project | **#1** → **#2** |
| Resume work right now | **#3** → **#5** (last entries) |
| Build the ROM | **#7** → **#8** |
| Flash or recover the phone | **#8** |
| Debug a boot failure | **#5** → **#10** → **#11** |
| Work on the root detector | **#17** |
| See the full history | **#5** |

## Status history (newest first)

1. **build-22 (in progress):** detector fix plan — libMEOW stub, AOT precompile,
   dex2oat CPU set `0-3`, framework timeouts 500→3000 ms.
2. **build-20 (booted):** release-keys, Lawnchair as system launcher, GApps,
   CameraGo, raw-super installer. See [INSTALL_METHOD.md](03-build-and-flash/INSTALL_METHOD.md).
3. **build-14:** OTG + TWRP survival + normal (non-Go) memory config.
4. **build-13:** first full boot to the launcher (flattened APEX + f2fs `/data`).

## Note on sources

The live build tree and phone-access scripts live on the build server
(`/root/android/lineage`), not in this repo. This repo holds the device tree plus
the notes above. Historical notes are preserved as written — when documents
disagree, trust the newest entry in [BUILD_FIXES.md](06-logbook/BUILD_FIXES.md).
