# Pickr — agent and release context

This file is the working context for any agent or developer touching this repo. The human-facing
intro and build instructions live in `README.md`; the release history lives in `CHANGELOG.md`.

## Overview
Pickr is a premium, minimalist macOS utility designed for professional audio workflows. It lives exclusively in the menu bar, providing instant, high-performance switching between audio input (microphones) and output (speakers/headphones) devices, coupled with live visual level metering and a system-wide global mute engine.

## App Store submission meta
Copy and assets required for App Store Connect.

### Basic info
- **App name**: Pickr
- **Subtitle**: Quick Audio Router & Mute
- **Bundle ID**: `fractals.pickr`
- **App Store ID**: `6761876281`
- **Vendor ID**: 93980849
- **Category**: Utilities / Productivity
- **Price point**: $2.99 USD

### App description

Pickr is the fastest way to manage your Mac's audio hardware. Designed for remote workers, podcasters, and musicians, Pickr strips away the complexity of System Settings and puts your entire audio rig directly in your menu bar.

**Key features:**
- **Instant routing**: switch between your AirPods, studio mic, and internal speakers with a single click.
- **Automation**: drive Pickr from Siri or the Shortcuts app, and let a shortcut change your devices when a call app launches or you plug in an interface.
- **Visual feedback**: real-time input metering lets you verify your levels before you jump into a call.
- **Global mute**: configure a custom keyboard shortcut to toggle your microphone system-wide.
- **Zero distraction**: a minimalist "Apple-native" UI that uses virtually zero idle CPU.
- **Custom nicknames**: rename complex hardware names (like "Logitech USB Headset H340") to simple aliases like "Office Mic".

### Keywords
`audio, microphone, mic, mute, switch, output, input, speaker, shortcuts, siri, macos, menu bar`

Kept to 94 characters against App Store Connect's 100-character limit. The previous draft copy in
this file was 103 characters and had never matched the live listing, so treat ASC as the source of
truth for what is actually published.

### What's new in 1.1

Pickr now works with Siri and the Shortcuts app.

Switch your input or output device, or toggle mute, without opening the menu bar. Set it up once in Shortcuts and Pickr can change devices for you — when a call app launches, when you plug in your audio interface, or on a schedule.

You can also just ask: "Switch input to Podcast Mic in Pickr."

Everything else works exactly as before.

---

## Technical architecture

### Tech stack
- **Language**: Swift, building in Swift 5 language mode (`SWIFT_VERSION = 5.0` in the Xcode project)
- **UI framework**: SwiftUI
- **Audio logic**: CoreAudio (hardware properties, routing, mute), AVFoundation (metering)
- **Automation**: App Intents (Shortcuts, Siri, Spotlight)
- **Dependencies**:
    - `KeyboardShortcuts`: industry-standard global hotkey engine.
- **Build system**: `XcodeGen` + native `Pickr.xcodeproj`, plus a SwiftPM path (`build.sh`) for local runs
- **Platform**: macOS 14+
- **Sandboxing**: App Sandbox enabled with microphone access (`com.apple.security.device.audio-input`). Hardened runtime enabled.

### Primary components

1. **AudioHardware (`AudioHardware.swift`)**
   - Single source of truth for CoreAudio. Deliberately non-isolated and UI-free so the App Intents layer can enumerate and switch devices without going through `AudioManager`.
   - Owns device enumeration (filtered to devices with streams, excluding CoreAudio's `CADefaultDeviceAggregate`), default input/output get and set, hardware mute support and state, and nickname lookup.

2. **AudioManager (`AudioManager.swift`)**
   - Central `@MainActor` state manager, exposed as a shared instance because a system-launched intent must reach the same object the panel renders from.
   - Builds its published state on top of `AudioHardware`, so the UI path and the automation path cannot drift.
   - Observes `kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultInputDevice` and `kAudioHardwarePropertyDefaultOutputDevice` to handle dynamic plug-and-play events (USB/Bluetooth).
   - Manages a temporary `AVAudioRecorder` with metering enabled for real-time level display, throttled to 20 FPS to maintain 0% idle energy impact. (Earlier revisions of this document described this as an `AVAudioEngine` tap; that was never what the code did.)

3. **App Intents (`PickrIntents.swift`)**
   - `PickrInputDevice` and `PickrOutputDevice` are separate `AppEntity` types, because one physical device can appear in both directions and App Intents resolves one query per entity type. Separate types make "switch input to X" unambiguous.
   - Device names come from `AudioHardware.displayName`, so custom nicknames resolve in Siri.
   - Three intents: `SetInputDeviceIntent`, `SetOutputDeviceIntent`, `ToggleMuteIntent`. All run without opening the app.
   - Intents re-resolve the target device at run time, so a device that has been unplugged since the shortcut was written reports back instead of silently failing.
   - Exactly one `AppShortcutsProvider` (`PickrAppShortcuts`) — more than one is a build-time error.

4. **UI architecture (`MenuView.swift`)**
   - Implements a split input/output hardware grid.
   - Designed for high-fidelity dark/light mode switching with native haptic feedback (`NSHapticFeedbackManager`).

5. **Settings engine (`SettingsView.swift`)**
   - Native macOS preferences pane (`Settings` scene).
   - Houses global hotkey recording, "Launch at Login" (via `ServiceManagement`), and developer support links.
   - Includes an in-app "Rate Pickr" link that opens the Mac App Store review flow.

6. **Persistence**
   - **LoginItemManager**: boots the app on login via Apple's modern Service Management APIs.
   - **NicknameStore**: persists custom device aliases via `UserDefaults` under `deviceNicknames`. `AudioHardware.nicknames()` reads the same key so the intents and the UI agree.

---

## Build and distribution

### Two build paths, and they differ in one important way

**Xcode project (used for App Store submission).** Required for anything involving App Intents:

```bash
xcodegen generate          # after editing project.yml
open Pickr.xcodeproj       # Product > Archive
```

**SwiftPM (`build.sh`, for local runs only).** Convenient, but SwiftPM cannot produce the
`Metadata.appintents` bundle that Shortcuts, Spotlight and Siri read to discover the intents. The
intents compile and are correct, they simply do not appear in Shortcuts from a SwiftPM-built app.
If you are testing the Siri or Shortcuts side, build from the Xcode project instead.

If the shortcuts look stale after installing a new build, it is almost always Launch Services
caching an old copy:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Pickr.app
```

### Toolchain: Xcode 26 does not run on macOS 27

Xcode enforces an operating-system compatibility check at launch. On macOS 27, Xcode 26.6 refuses to
open with *"The version of Xcode installed on this Mac is not compatible with macOS Golden Gate."* The
App Store copy lags too — Xcode 27 reaches the App Store alongside macOS 27 itself.

Use the **Xcode 27 Release Candidate** from
[developer.apple.com/download](https://developer.apple.com/download/all/). Apple opened App Store
submissions built with it on 9 September 2026, ahead of the macOS 27 release, so an RC build can be
uploaded for review — a **beta** build cannot (Organizer rejects it with `90301`, "Apple is not
currently accepting applications built with this version of Xcode").

Worth knowing: `xcodebuild` from Xcode 26.6 *does* still run on macOS 27 even though the GUI does not,
so a command-line archive with 26.6 remains possible in a pinch. The RC is the supported path.

### Check which toolchain actually built an archive

Do not trust which Xcode you think you used. Read the SDK out of the archived binary:

```bash
vtool -show-build ~/Library/Developer/Xcode/Archives/<date>/<name>.xcarchive/Products/Applications/Pickr.app/Contents/MacOS/Pickr | grep -E "platform|minos|sdk"
# sdk 26.5 -> Xcode 26.6, acceptable
# sdk 27.0 -> macOS 27 SDK
```

The archive's own `Info.plist` also records every distribution attempt — `preparationEvent` (did
signing and provisioning succeed?) and `uploadEvent` (the exact rejection, code and timestamp).

### Submission checklist
1. **Version**: `project.yml` is the single source. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` there, then run `xcodegen generate`.
2. **Archive**: use `Product > Archive` in Xcode. Archives are universal by design (see below).
3. **Privacy**: `NSMicrophoneUsageDescription` is declared in `project.yml`, not in `Info.plist` (see below).
4. **Sandbox**: ensure `Pickr.entitlements` includes the audio input capability.
5. **Assets**: all icons are hosted in `Assets.xcassets` (1024px down to 16px).

### Info.plist is generated — never hand-edit it

`xcodegen generate` **rewrites `Info.plist` from the `info.properties` block in `project.yml`**.
Anything not declared there is silently dropped from the built app, and any hand-edit is lost on the
next generation. This was confirmed the hard way: a version bump applied directly to `Info.plist`
reverted to 1.0 the moment `xcodegen` ran, and `LSMinimumSystemVersion` plus
`LSApplicationCategoryType` had been missing from generated builds because they were never declared
in `project.yml`. Both are now declared, and the version keys resolve from
`$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` so there is only one place to bump.

The microphone usage string previously disagreed between `Info.plist` and `project.yml`. The
project.yml block now carries the `Info.plist` wording ("Pickr displays a live level meter so you can
see your mic is active."), because that is the shorter, plainer one. Confirm against what actually
shipped if a change there would matter for App Review.

### Architecture note
Archives are **universal** — `ARCHS = arm64 x86_64` with `ONLY_ACTIVE_ARCH = NO`. That is what we
want: the deployment target is macOS 14, and Intel Macs still run 14 and 15, so the x86_64 slice
serves real users. A local `-destination "platform=macOS"` build is arm64-only, so don't be alarmed
that the DerivedData product differs from the archive.

macOS 27 is Apple silicon only — per Apple's own release announcement, **macOS 26 is the final
release supporting Intel Macs and Rosetta**. That does not change the decision above: Intel users on
macOS 14 through 26 are a real audience, so keep the x86_64 slice. Apple explicitly offers arm64-only
as an option ("set the Xcode build architecture to arm64 only") for anyone who wants to drop them;
Pickr does not need to.

---

*Fractals Collective. Made in Aldinga, 2026.*
