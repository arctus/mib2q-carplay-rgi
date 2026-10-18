# Android Auto route guidance in the Virtual Cockpit

_Android Auto turn-by-turn on the stock cluster and HUD, through the same chain CarPlay uses. Opt-in._

---

## What it does

With the opt-in marker present and an Android phone in Android Auto, the patched HMI turns
Android Auto's next-turn data into the frames the CarPlay hook produces for an iPhone, so the
existing `RouteGuidance` -> `BAPBridge` chain drives the Virtual Cockpit and HUD:

- maneuver icon, distance and bargraph, and route text (BAP FctIDs 17/18/19/20/23/39/49);
- the same maneuver on the HUD;
- Android Auto cover art on the cluster media screen.

The cluster stays in its stock context (74) and draws the maneuver with its own graphics.

Not in this slice: the 3D maneuver arrow overlay (ctx 80; `AltScreenModule`, the single context
writer, runs only for CarPlay, so `BAPBridge` skips the custom renderer during an Android Auto
session), the Google Maps / Waze **map video** on the cluster (needs the `gal` receiver hook),
lanes (they come from that hook's `/tmp/aa_lanes`), and roller zoom (Android Auto has no zoom
command for a cluster display).

## Turning it on and off

The HMI reads `/mnt/app/carplay_aa.enabled` (or `/tmp/carplay_aa.enabled`) when it starts;
`carplay_aa.disabled` in either place still wins. **Reboot the head unit after changing it.**

- `android_auto_on_MoreIncredibleBash/`: creates the marker (M.I.B. -> Run Custom Script).
- `android_auto_off_MoreIncredibleBash/`: removes it.

Without the marker Android Auto stays stock. The two replaced stock classes
(`AndroidAuto2ListenerDistributor`, `nav/AndroidAuto2NavHandler`) are then still in the jar
but only differ from stock by a `Vector` listener list and a guarded call that returns at once.

## How it is wired [code]

| Piece | Role |
| --- | --- |
| `java_patch/de/.../androidauto2/AndroidAuto2ListenerDistributor.java` | stock class rebuilt; its constructor calls `AaBridge.attach()` |
| `java_patch/de/.../androidauto2/nav/AndroidAuto2NavHandler.java` | stock class rebuilt; subscribes the next-turn attributes through `AaBridge.subscribeNavigation()` |
| `com.luka.carplay.aa.AaBridge` | Android Auto device ACTIVATING/ACTIVE -> `CarPlayApp.onActivateAndroidAuto()`; next-turn events -> `AaRgState` -> `CarplayBus.injectLocal(EVT_RGD_UPDATE, STICKY, ...)` |
| `AaRgState`, `AaManeuverMap` | Android Auto turn events -> the `RouteGuidance` text frame (one maneuver slot, `m0_ver` bumped per turn, `route_generation` per route) |
| `AaCoverArt`, `PngCover` | Android Auto artwork -> `CoverArt.publishLocal()` |
| `CarPlayApp` | session **owner**: `OWNER_CARPLAY` or `OWNER_ANDROID_AUTO`. Only `RgdModule` runs for Android Auto; `isActive()` still means "a CarPlay session", so every CarPlay-only caller is unchanged |
| `RgdModule` | CarPlay keeps the whole-session takeover; Android Auto takes over per route (`BAPBridge.onStart()` / `onShutdown()`), so Audi navigation keeps working with an Android phone connected |

The two stock classes are byte-identical in the US MU1316, EU MU1329 and CN MU1003 jars, so
both shipped jars carry the same replacements.

## Status [open]

Car-tested upstream by kamgurgul on an Audi A5 F5, `MHI2Q_ER_AUG22_P5152` / MU1329, against a
September base of this project. This port onto the current tree is **not car-tested yet**.
Host tests: `tests/AaRouteStateTest.java` (64 checks) and the `owners` scenario of
`CarPlayAppLifecycleTest`, both run by `scripts/test_java_transports.sh`.

## Credits

Ported from [kamgurgul/mib2q-carplay](https://github.com/kamgurgul/mib2q-carplay), which adapted
it from [wasimlhr/mib2q-android-auto-cluster](https://github.com/wasimlhr/mib2q-android-auto-cluster).
Both GPL-3.0-or-later.

## Next: the Android Auto map video on the cluster [open]

kamgurgul's cluster video (Google Maps / Waze in the cockpit) is a `gal` hook,
`libaa_cluster_hook.so`, preloaded by a `children.gal` wrapper. It is not ported yet, for four
reasons that each need either data from the car or a change that must be validated on it:

1. **A `gal` profile for this firmware.** The hook only runs when both `libautoreceiver.so`
   and `gal` match a known profile: it writes into receiver objects and pins two `gal`
   addresses. For `MHI2Q_ER_AUG22_P5092` the receiver is already known (the MIBSI P5092 package
   pins it at SHA-256 `6ef4abea8264...`, the MU0918/P5152 receiver kamgurgul validated), but
   `gal` differs per build. The logging card now copies both files to
   `carplay_logs/aa/` once per card; `scripts/aa_receiver_profile.py gal libautoreceiver.so`
   then prints the profile entry.
2. **The renderer.** `altscreen_render` decodes a fixed 1440x542 stream (`ALTSCREEN_W/H`,
   `PortSettingsChanged` ignored, full-frame texture coordinates) and is the TCP server on
   :19831 with legacy or v2 framing. The Android Auto cluster stream is 1920x1080 with the
   useful 1440x540 viewport centred (margins 480x540), and kamgurgul's tee is itself a server
   on :19821 sending raw Annex-B. So the tee has to become a :19831 client in legacy framing,
   and the renderer has to size the decoder and crop per stream. The renderer survives phone
   generations (the monitor adopts it), so a per-process environment cannot select the mode.
   This touches the CarPlay renderer and needs a car to validate.
3. **Cluster contexts.** `AltScreenModule`, the single writer of cluster contexts, has to run
   for Android Auto to switch to ctx 81 on `VIDEO_ON`; the stock "navigation on mobile device"
   layout must be held off while the video shows (kamgurgul's `VcMapViewGate` in
   `ClusterService.updateGALState`); the cockpit view goes to the hook through
   `/tmp/aa_cluster_view`; and `BAPBridge` can then use the 3D arrow overlay for Android Auto too.
4. **Install.** A marker-gated `aa_startup.sh` as `children.gal` in
   `smartphone_integrator.json` that also starts the renderer monitor with `gal` as the owner
   (`dio_manager`, and with it the CarPlay monitor, is not running during an Android Auto
   session), and its restore in the uninstaller.

Order: collect `carplay_logs/aa/` on the first car session, port the hook with the P5092
profile, then the renderer change, then contexts and install.
