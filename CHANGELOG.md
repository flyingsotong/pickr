# Changelog

All notable changes to Pickr. Version numbers match the Mac App Store release.

## 1.1 — unreleased

### Added
- **Global shortcuts for cycling devices.** Next input and next output join toggle mute, each configurable in Settings. A hotkey has no visible target to aim at, so cycling wraps at the end of the list, and the menu bar label is the confirmation.
- **Menu bar label options.** The item can show the mute glyph alone, or the glyph with either the input or the output device name. Naming the device is also the only feedback you get when a shortcut or a Siri phrase changes it, without a panel open.
- **Siri and Shortcuts support via App Intents.** Three actions are now exposed to the system: switch audio input, switch audio output, and toggle microphone mute. Each can be driven from the Shortcuts app, from Siri, or from any automation that can run a shortcut. Devices are offered by name, and custom nicknames resolve, so "switch input to Podcast Mic" works even when the underlying hardware is called something unreadable.
- App shortcuts for the three intents, so the phrases work in Siri without the user building a shortcut first.
- A note in Settings explaining that the app is now automatable.

### Changed
- The mute OSD now uses Liquid Glass on macOS 26 and later (`Glass.swift` holds the single availability-aware helper), with the previous `NSVisualEffectView` vibrancy retained as the fallback. The deployment target stays at macOS 14, so nothing is dropped for older systems or Intel Macs.
- CoreAudio access moved into a single `AudioHardware` type shared by the menu bar UI and the App Intents layer, so the two paths cannot drift. The audio behaviour is unchanged.
- `AudioManager` is now a shared instance, because a system-launched intent must reach the same state object the panel renders from.
- Version bumped to 1.1 (build 2).

### Fixed
- **Settings opened behind other windows.** Pickr is an accessory app, so it is usually not the active application, and `SettingsLink` showed the window underneath whatever you were working in. The Settings row now activates the app before opening it.
- **The Settings pane could not be resized or scrolled.** The content was pinned to a fixed 450×500 frame, so anything past that boundary was unreachable. Fixed width, minimum height, and the window scrolls now.
- Device names in the panel wrapped awkwardly, and truncating them to one line lost the last word ("MacBook Pro Spe…"). They are now trimmed of vendor boilerplate (`AudioHardware.trimmedName`) and allowed to wrap across at most two lines, so a longer name reads in full.
- The `Show` picker in Settings drew its title outside the content column, leaving it visibly left of every other row label. It is now a hand-rolled label row matching the rows above, and both section footers wrap instead of truncating mid-sentence.
- Device rows stacked three trailing controls at varying opacity. A view at `.opacity(0)` still receives hits, so an invisible "confirm rename" button was covering the trailing edge of every row — tapping near the right side of a device fired rename instead of selecting it. Only the applicable control is built now.
- `Info.plist` is now generated completely from `project.yml`. Running `xcodegen generate` had been resetting the version to 1.0/1 and silently dropping `LSMinimumSystemVersion` and `LSApplicationCategoryType`, because they were never declared in the `info.properties` block. Version keys now resolve from `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`, so there is a single place to bump.

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
