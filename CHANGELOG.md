# Changelog

All notable changes to Pickr. Version numbers match the Mac App Store release.

## 1.1 — unreleased

### Added
- **Siri and Shortcuts support via App Intents.** Three actions are now exposed to the system: switch audio input, switch audio output, and toggle microphone mute. Each can be driven from the Shortcuts app, from Siri, or from any automation that can run a shortcut. Devices are offered by name, and custom nicknames resolve, so "switch input to Podcast Mic" works even when the underlying hardware is called something unreadable.
- App shortcuts for the three intents, so the phrases work in Siri without the user building a shortcut first.
- A note in Settings explaining that the app is now automatable.

### Changed
- CoreAudio access moved into a single `AudioHardware` type shared by the menu bar UI and the App Intents layer, so the two paths cannot drift. The audio behaviour is unchanged.
- `AudioManager` is now a shared instance, because a system-launched intent must reach the same state object the panel renders from.
- Version bumped to 1.1 (build 2).

### Documentation
- Corrected the metering description: it has always used `AVAudioRecorder` with metering enabled, not an `AVAudioEngine` tap.
- Corrected the toolchain description: the Xcode project builds in Swift 5 language mode, not Swift 6 with strict concurrency.
- Documented the App Intents metadata requirement, which determines whether the actions are visible to the system.

## 1.0 — 8 April 2026

Initial release.

- Instant switching between input and output audio devices from the menu bar
- Live input level metering, throttled to 20 FPS
- System-wide microphone mute via a configurable global shortcut
- Custom device nicknames
- Launch at login
