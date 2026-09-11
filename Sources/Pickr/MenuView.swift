import SwiftUI
import AppKit
import KeyboardShortcuts

struct MenuView: View {
    @EnvironmentObject var audio: AudioManager
    @EnvironmentObject var nicknames: NicknameStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("INPUT")
            deviceList
            Divider().padding(.vertical, 4)
            sectionHeader("OUTPUT")
            outputDeviceList
            Divider().padding(.vertical, 4)
            actions
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 280)
        .padding(.vertical, 4)
        .onAppear { audio.startLevelMetering() }
        .onDisappear { audio.stopLevelMetering() }
    }

    // MARK: - Sections

    private var deviceList: some View {
        Group {
            if audio.devices.isEmpty {
                Text("No input devices found")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                ForEach(audio.devices) { device in
                    DeviceRow(
                        device: device,
                        isActive: device.id == audio.defaultDeviceID,
                        level: device.id == audio.defaultDeviceID ? audio.inputLevel : 0,
                        nickname: nicknames.nickname(for: device.name)
                    ) {
                        audio.setDefault(device.id)
                    } onRename: { name in
                        nicknames.setNickname(name, for: device.name)
                    }
                }
            }
        }
    }

    private var outputDeviceList: some View {
        Group {
            if audio.outputDevices.isEmpty {
                Text("No output devices found")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                ForEach(audio.outputDevices) { device in
                    DeviceRow(
                        device: device,
                        isActive: device.id == audio.defaultOutputDeviceID,
                        level: nil, // Outputs do not require generic audio metering
                        nickname: nicknames.nickname(for: device.name)
                    ) {
                        audio.setDefaultOutput(device.id)
                    } onRename: { name in
                        nicknames.setNickname(name, for: device.name)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if audio.supportsMute {
                MuteRow(isMuted: audio.isMuted, shortcutText: shortcutText) { audio.toggleMute() }
            } else {
                UnavailableMuteRow()
            }
            // Not `SettingsLink`: a menu-bar app is an accessory, so it is usually not the active
            // application, and the Settings window opened behind whatever the user was working in.
            // Activate first, then open — that is what brings it to the front.
            ActionRow(label: "Settings", icon: "gearshape") {
                NSApp.activate()
                openSettings()
            }
            Divider().padding(.vertical, 4)
            ActionRow(label: "Quit Pickr", icon: "xmark.circle") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var shortcutText: String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleMute) {
            return shortcut.description
        }
        return "Set shortcut"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: AudioDevice
    let isActive: Bool
    var level: Float? = nil
    let nickname: String?
    let onSelect: () -> Void
    let onRename: (String) -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editText = ""

    var displayName: String { nickname ?? AudioHardware.trimmedName(for: device.name) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "mic.fill" : "mic")
                .font(.system(size: 13))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 18)

            if isEditing {
                TextField("", text: $editText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .onSubmit { commitRename() }
                    .onExitCommand { cancelRename() }
            } else {
                Text(displayName)
                    .font(.system(size: 13, weight: isActive ? .medium : .regular))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if isActive && !isEditing {
                if let validLevel = level {
                    LevelMeterView(level: validLevel)
                } else {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.green)
                        .frame(width: 44, height: 16, alignment: .trailing)
                }
            }

            trailingIcon
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(rowBackground)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { if !isEditing { 
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            onSelect() 
        } }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isEditing)
    }

    /// Only the applicable control is built, instead of three stacked at varying opacity.
    /// A view at `.opacity(0)` still receives hits, so the previous version left an invisible
    /// "confirm rename" button covering the trailing edge of every row — tapping near the right
    /// side of a device row fired rename instead of selecting the device.
    private var trailingIcon: some View {
        Group {
            if isEditing {
                Button(action: commitRename) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else if isHovered {
                Button(action: startEditing) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 16, height: 16)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isHovered && !isEditing
                  ? Color(NSColor.selectedContentBackgroundColor).opacity(0.12)
                  : .clear)
    }

    private func startEditing() {
        editText = displayName
        isEditing = true
    }

    private func commitRename() {
        onRename(editText)
        isEditing = false
    }

    private func cancelRename() {
        isEditing = false
    }
}

// MARK: - Level Meter

struct LevelMeterView: View {
    let level: Float

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.secondary.opacity(0.15))
            Capsule()
                .fill(meterColor)
                .frame(width: max(3, 44 * CGFloat(level)))
        }
        .frame(width: 44, height: 4)
        .animation(.easeOut(duration: 0.08), value: level)
    }

    private var meterColor: Color {
        level > 0.75 ? Color.red.opacity(0.8)
        : level > 0.45 ? Color.orange.opacity(0.8)
        : Color.green.opacity(0.8)
    }
}

// MARK: - Mute Row

struct MuteRow: View {
    let isMuted: Bool
    let shortcutText: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isMuted ? "mic.slash.fill" : "mic.slash")
                .font(.system(size: 13))
                .foregroundStyle(isMuted ? Color.red : .secondary)
                .frame(width: 18)
            Text(isMuted ? "Unmute" : "Mute")
                .font(.system(size: 13))
                .foregroundStyle(isMuted ? Color.red : .primary)
            Spacer()
            Text(shortcutText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.12) : .clear)
        )
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            action()
        }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

struct UnavailableMuteRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.slash")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
            Text("Mute Unavailable")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Generic Action Row

struct ActionRow: View {
    let label: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.12) : .clear)
        )
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            action()
        }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

