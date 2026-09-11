# Pickr

A minimalist macOS menu bar utility for switching audio input and output devices, with live level
metering and a system-wide microphone mute.

- **[CONTEXT.md](CONTEXT.md)** — architecture, App Store copy, and the release context an agent or developer needs
- **[CHANGELOG.md](CHANGELOG.md)** — release history

## Requirements

- macOS 14 or later
- Xcode 15 or later (26+ to build against the macOS 27 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Building

### Xcode project (use this for releases, and for anything touching App Intents)

```bash
xcodegen generate
open Pickr.xcodeproj
```

Run from Xcode, or `Product > Archive` to submit.

### SwiftPM (quick local runs)

```bash
./build.sh
open Pickr.app
```

`build.sh` compiles with SwiftPM and assembles the bundle by hand. It is fine for UI work, but it
**cannot generate the `Metadata.appintents` bundle**, so the Siri and Shortcuts actions will not
appear in a build made this way. SwiftPM has no equivalent of Xcode's const-values output, which is
what `appintentsmetadataprocessor` reads. If you are testing automation, build from the Xcode
project.

### If the shortcuts don't show up

Launch Services often caches an older copy of the bundle:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Pickr.app
```

## Automation

Pickr exposes three actions to Shortcuts, Siri, and Spotlight:

| Action | What it does |
|---|---|
| Switch Audio Input | Sets the default microphone |
| Switch Audio Output | Sets the default speaker or headphones |
| Toggle Microphone Mute | Mutes or unmutes the default microphone |

Device names come from your custom nicknames, so `Switch input to Podcast Mic in Pickr` works even
when the hardware reports a name nobody can read.

## Releasing

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`
2. `xcodegen generate`
3. Update `CHANGELOG.md` and the submission copy in `CONTEXT.md`
4. `Product > Archive` in Xcode

`Info.plist` is **generated** by `xcodegen generate` from the `info.properties` block in
`project.yml`. It is a build artifact — hand-editing it does not survive the next generation, and
anything not declared in that block will be missing from the shipped app. Add new keys to
`project.yml`, not to the plist.

## License

Proprietary. Copyright Fractals Collective.
