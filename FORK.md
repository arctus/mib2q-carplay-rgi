# arctus fork of luka-dev/mib2q-carplay-rgi

Working fork for one car: **Audi Q7 4M**, `MHI2Q_ER_AUG22_P5092`, MU1329, Virtual Cockpit + HUD,
Bose (`Bose6416A_P3`), M.I.B. installed. Upstream: https://github.com/luka-dev/mib2q-carplay-rgi
(GPL-3.0-or-later, see `LICENSE` and `NOTICE.md`; everything added here is under the same licence).

## Branches

| Branch | Purpose | Rule |
|---|---|---|
| `main` | exact mirror of `upstream/main` | fast-forward only, never commit here |
| `fork` | this file, `fork/` helpers, and merges of the feature branches for our own SD package | merge, do not rebase once pushed |
| `feature/layout-options` | cluster layout work (backlog 1) | based on `main`, so it can go upstream as a PR |
| `feature/android-auto-vc` | Android Auto on the VC (backlog 2) | based on `main`, PR-able |

Sync with luka:

```sh
git fetch upstream --tags
git checkout main && git merge --ff-only upstream/main && git push origin main --tags
git checkout fork && git merge main
```

## Building

### Baseline, verified 2026-10-18

Upstream `ab3317c` (= tag `MHI2Q-2026-10-18`, = the release zip) was rebuilt with luka's own
unmodified scripts. **All four native binaries are byte-identical to the release zip**:

| File | SHA-256 (release = our build) |
|---|---|
| `libcarplay_hook.so` | `bb82bcb93134212cc53535f4761993a22188386c3cf26a40b0910e2f7a5ba098` |
| `libcarplay_apac.so` | `9bf074346d953ccbc02576492c990815572f9886c81be1a804e88a8f629d88dd` |
| `maneuver_render` | `829a63f6c0e6b8c80fb30ebca48fa9f3a7b96e666b58f10549b043eb80690c71` |
| `altscreen_render` | `4fbb6093650dce8a6b862a6a09036079d423d8f2c5da4f33cc745e1e8204511b` |

The two jars are **not** byte-identical, and the reasons are all build-environment, not source:

- the release build ID is `MHI2Q-2026-05-16-81-gab3317c-dirty` (luka built from a working tree
  with local edits); set `CARPLAY_BUILD_ID` to compare;
- source encoding: one string in `CombiMapController` contains a non-ASCII character, so build with
  a UTF-8 locale (`LC_ALL=C.UTF-8`), or that string is mangled;
- compiler: the release used Azul Zulu `1.8.0_412`, which emits `jsr`/`ret` for `finally` blocks at
  `-target 1.4`; OpenJDK `1.8.0_504` inlines them. That alone accounts for the remaining 5 differing
  classes (`AltScreenModule`, `UpmixSetting`, `BAPBridge`, `RendererServer`, `VCTextData`).
  **Use Zulu 8u412** (`JAVA8_HOME`) when a byte-identical jar matters.

With UTF-8 and the same build ID, 154 of 159 classes are identical.

### On your PC (normal route: Docker)

luka's scripts call `docker run ... qnx65-armv7-toolchain:latest`. On Windows use **WSL2 (Ubuntu)
plus Docker Desktop with the WSL backend**, or Docker Engine inside WSL. Keep the checkout inside the
WSL filesystem for speed (or build from `/mnt/c/Source/PCISolutions/mib2q-carplay-rgi`, slower).

```sh
git clone https://github.com/luka-dev/qnx65-armv7-toolchain
cd qnx65-armv7-toolchain && ./host-scripts/qnx-run.sh build      # once, 30-60 min (builds GCC 8.5)
cd /path/to/mib2q-carplay-rgi
export JAVA8_HOME=/path/to/zulu8.78.0.19-ca-jdk8.0.412-linux_x64 LC_ALL=C.UTF-8
./scripts/build_hook.sh                     # build/unprotected/libcarplay_hook.so (+ apac)
./scripts/prepare_install.sh build/unprotected   # jar + renderers + install zip in build/
```

### Without Docker

`fork/build-native-toolchain.sh` installs the same toolchain natively on Ubuntu 24.04 (what the
2026-10-18 baseline used, because the build sandbox could not run Docker). `fork/bin/docker` then
stands in for `docker`, so luka's scripts run unchanged: `PATH=$PWD/fork/bin:$PATH ./scripts/build_hook.sh`.
Its GCC 8.5.0 source came from the `releases/gcc-8.5.0` tag of the GitHub mirror rather than the GNU
tarball; binutils 2.38 came from Ubuntu's orig tarball, whose SHA-256 equals GNU's.

### Host tests: macOS-only today

`scripts/run_tests.sh` is written against macOS clang. On Linux (and so WSL) it stops early:

1. GCC 13 rejects `hook/audio/scene_mask.c:533` under `-pedantic -Werror` (pointer-to-array
   qualifier mismatch); use clang.
2. `-std=c99` hides `clock_gettime` on glibc; tests need `-D_DEFAULT_SOURCE`.
3. `tests/altscreen_sink_fixture.h` waits on `gpu_cond` (a default, CLOCK_REALTIME condition) with a
   CLOCK_MONOTONIC deadline from `_AbsTimeoutMs`, so every wait times out at once off macOS
   (`alt_mailbox` aborts). `altscreen_sink_test` fails the same way next.

With clang and `-D_DEFAULT_SOURCE` the suite passes 39 checks and then aborts in `alt_mailbox`
(item 3). Patching that one fixture lets it reach 44 before `altscreen_sink_test` aborts. Fixing
these is backlog item 0 and a good first PR to luka.

## Backlog

### 0. Linux/WSL host tests (small, upstreamable)

Fix the three items above in the test build lines and fixtures, never in shipped code. Done when
`scripts/run_tests.sh` passes on Ubuntu 24.04 with both gcc and clang.

### 1. Cluster layouts (`feature/layout-options`)

**What luka already does.** The hook declares four view areas for the 1440x542 panel with nested
safe areas (fullscreen `270,90 900x290`, smallscreen `90,90 360x300`, classic compact centred,
sport compact), and `AltScreenModule` picks them from `NAV_VIEW_SIZE_CHOICE` (full/small) plus the
skin (`LastmodeStorage` 1 = Sport, 0 = Classic). So the phone is asked to lay out for the layout,
rather than the video plane being moved afterwards.

**Step 1, on the car before writing code:** connect CarPlay with a route and cycle Classic / Sport x
large / small with the View button. Note where the vehicle marker and the turn card sit, and
whether the map is ever hidden behind the single Sport dial. If all four are right, most of
Allemon's work is not needed here.

**Candidates from other projects:**

| Feature | Where it is done | Note |
|---|---|---|
| Sport: map plane follows the stock small-stage offset (-476 px) | Allemon `java_patch/com/luka/carplay/cluster/AltScreenPlacement.java` | probably unnecessary given luka's per-layout view areas; verify in step 1 |
| Configurable view area for apps that ignore the safe area (Amap, Baidu) | Allemon `hook/altcluster/alt_viewarea.c`, `/mnt/app/root/hooks/cluster_viewarea.cfg` | only matters for non-Apple map apps |
| Per-view horizontal shift (`full_dx` / `small_dx`) | Allemon `cluster_shift.cfg` | tuning aid |
| Map layout presets (card top / right / no ETA) | Allemon GEM "Cluster map layout" | needs a GEM or MMI switch |
| Layout follows `CombiBAPListener.setMapPresentation` because `NAV_VIEW_SIZE_CHOICE` can freeze during CarPlay ownership; `adjacentViewAreas` naming the other two areas | ganm-afk, aberbic issue #5 (Q7 4M with SQ7 VC, Tegra) | same Audi HMI classes; check whether our Q7 shows the freeze |
| Startup compass when a route is already active at connect | open in aberbic #5; luka `TODO.md` has a related "Navigation is initializing" item | test on our car |

**Licensing:** Allemon's repository has **no licence file**, so its code cannot be copied into this
GPL tree. Reimplement from the documented behaviour, or ask Allemon to license it first.
kamgurgul and luka are GPL-3.0 and can be merged.

### 2. Android Auto on the VC (`feature/android-auto-vc`)

**Best source: `kamgurgul/mib2q-carplay`** (GPL-3.0, a luka fork, so the same packages and process
layout). It adds `aa_hook/` (`libaa_cluster_hook.so`, `LD_PRELOAD` into `gal` through
`aa_startup.sh`), `java_patch/com/luka/carplay/aa/ClusterGalSink.java`,
`de/audi/app/terminalmode/smartphone/androidauto2/*`, and reuses `altscreen_render` on TCP 19821.
Verified on an A5 F5 with MU1329 (`P5152`): turn arrow, lanes, route text on VC and HUD, AA cover
art, map video following Large/Classic/Sport. No zoom of the AA cluster map (Android Auto has no
command for it). Docs: its `docs/android-auto/overview.md` and `firmware-porting.md`.

**Our firmware fits its receiver profile.** The hook writes into objects of the stock
`libautoreceiver.so` and needs a profile for that exact build. Our P5092's receiver is
SHA-256 `6ef4abea8264ab7787b0ecb3fe278a65488301f703148d0175010f7b228bdaf6` (from the MIBSI P5092
package's `install_product.sh` `RECEIVER_SHA`, in the audicluster archive), which is exactly the
MU0918/P5152 receiver kamgurgul already has a built-in profile for. Only `gal` differs per build;
confirm our `gal` hash with a logging card before trusting the profile.

**Plan:**

1. Merge-port kamgurgul's AA parts onto current `main` behind `ANDROID_AUTO=1` (default off until
   car-tested), keeping luka's newer CarPlay altscreen, telephony and lane work.
2. Ownership: CarPlay and Android Auto share Screen/AltScreen/Rgd modules through the session owner
   file (`/tmp/aa_supervisor.owner`), as kamgurgul does.
3. Installer: add the `gal` child (`aa_startup.sh`) and the receiver-hash check; keep the firmware
   gate.
4. Also read for reference: `wasimlhr/mib2q-android-auto-cluster` (GPL-3.0, MU0918, AA-only fork)
   and audicluster `docs/06-android-auto-cluster.md`. MIBSI is closed and paid: use it only to learn
   behaviour, never copy from it.

### 3. Q7-specific checks before first install

- Bose amplifier: luka's 5.1 upmix was developed on B&O and is untested on Bose; the installer
  gates 5.1 on the amplifier coding.
- `navignore`: luka's installer deletes M.I.B.'s NavActiveIgnore jar without a backup.
- Prepare the rescue card (`rescue_MoreIncredibleBash/`, needs M.I.B. 3.7.1) and a full M.I.B.
  backup before the first install.
