# pickr
# Pickr - Commercial Release Context

## Overview
Pickr is a premium, minimalist macOS utility designed for professional audio workflows. It lives exclusively in the menu bar, providing instant, high-performance switching between audio input (microphones) and output (speakers/headphones) devices, coupled with live visual level metering and a system-wide global mute engine.

## App Store Submission Meta
This section contains all standard assets and copy required for App Store Connect submission.

### Basic Info
- **App Name**: Pickr
- **Subtitle**: Quick Audio Router & Mute
- **Bundle ID**: `fractals.pickr`
- **App Store ID**: `6761876281`
- **Category**: Utilities / Productivity
- **Price Point**: $2.99 USD

### App Description
Pickr is the fastest way to manage your Mac's audio hardware. Designed for remote workers, podcasters, and musicians, Pickr strips away the complexity of System Settings and puts your entire audio rig directly in your menu bar.

**Key Features:**
- **Instant Routing**: Switch between your AirPods, Studio Mic, and internal speakers with a single click.
- **Visual Feedback**: Real-time Input Metering allows you to verify your levels before you jump into a call.
- **Global Mute**: Configure a custom keyboard shortcut to toggle your microphone system-wide.
- **Zero Distraction**: A minimalist "Apple-native" UI that uses virtually zero idle CPU. 
- **Custom Nicknames**: Rename complex hardware names (like "Logitech USB Headset H340") to simple aliases like "Office Mic".

### Keywords
audio, route, microphone, speaker, mute, switch, hardware, utility, macos, menu bar, level meter, sound

---

## Technical Architecture

### Tech Stack
- **Language**: Swift 6 (Strict Concurrency Enabled)
- **UI Framework**: SwiftUI
- **Audio Logic**: CoreAudio (Hardware Properties), AVFoundation (Metering Tap)
- **Dependencies**: 
    - `KeyboardShortcuts`: Industry-standard global hotkey engine.
- **Build System**: `XcodeGen` + Native `Pickr.xcodeproj`
- **Platform**: macOS 14+
- **Sandboxing**: App Sandbox enabled with microphone access (`com.apple.security.device.audio-input`). Hardened Runtime enabled.

### Primary Components

1. **AudioManager (`AudioManager.swift`)**
   - Central `@MainActor` state manager for all discovery and routing logic.
   - Observes `kAudioHardwarePropertyDevices` to handle dynamic plug-and-play events (USB/Bluetooth).
   - Manages a temporary `AVAudioEngine` tap for real-time RMS metering, throttled to 20 FPS to maintain 0% idle energy impact.
   - Uses a single engine configuration-change observer to keep metering stable across device changes.

2. **UI Architecture (`MenuView.swift`)**
   - Implements a split Input/Output hardware grid.
   - Designed for high-fidelity dark/light mode switching with native haptic feedback (`NSHapticFeedbackManager`).

3. **Settings Engine (`SettingsView.swift`)**
   - Native macOS Preferences Pane (`Settings` scene).
   - Houses global hotkey recording, "Launch at Login" (via `ServiceManagement`), and developer support links.
   - Includes an in-app “Rate Pickr” link that opens the Mac App Store review flow.

4. **Persistence**
   - **LoginItemManager**: Boots the app on login via Apple's modern Service Management APIs.
   - **NicknameStore**: Persists custom device aliases via `UserDefaults`.

---

## Build & Distribution
Pickr is built using a native Xcode workflow.

### Project Generation
The `.xcodeproj` is managed by `XcodeGen`. If `project.yml` is modified, regenerate using:
```bash
xcodegen generate
```

### Submission Checklist
1. **Archive**: Use `Product > Archive` in Xcode.
2. **Privacy**: Ensure `NSMicrophoneUsageDescription` in `Info.plist` is up to date.
3. **Sandbox**: Ensure the `.entitlements` file includes the Audio Input capability.
4. **Assets**: All icons are hosted in `Assets.xcassets` (1024px down to 16px).

---
*Fractals Collective. Made in Aldinga, 2026.*
