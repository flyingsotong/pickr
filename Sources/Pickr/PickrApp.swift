import CoreAudio
import SwiftUI

@main
struct PickrApp: App {
    @StateObject private var audio = AudioManager.shared
    @StateObject private var nicknames = NicknameStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(audio)
                .environmentObject(nicknames)
        } label: {
            MenuBarLabel(audio: audio, nicknames: nicknames)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

/// The menu bar item itself.
///
/// The glyph carries the mute state and is always shown; the device name beside it is optional,
/// because the menu bar is shared space and some users want the icon alone. It is also the only
/// feedback available when a device is changed by a global shortcut or a Siri phrase, so keeping
/// it on at least one of the two devices is worth encouraging.
struct MenuBarLabel: View {
    @ObservedObject var audio: AudioManager
    @ObservedObject var nicknames: NicknameStore

    @AppStorage("menuBarLabel") private var mode: MenuBarLabelMode = .input

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: audio.isMuted ? "mic.slash.fill" : "mic.fill")
                .foregroundStyle(audio.isMuted ? Color.red : Color.primary)

            switch mode {
            case .iconOnly:
                EmptyView()
            case .input:
                deviceLabel(for: audio.defaultDeviceID, in: audio.devices, fallback: "Mic")
            case .output:
                deviceLabel(for: audio.defaultOutputDeviceID, in: audio.outputDevices, fallback: "Speaker")
            }
        }
    }

    @ViewBuilder
    private func deviceLabel(for deviceID: AudioDeviceID, in list: [AudioDevice], fallback: String) -> some View {
        if let name = shortName(for: deviceID, in: list, fallback: fallback) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 100)
        }
    }

    /// A nickname if one is set, otherwise the raw name with vendor boilerplate trimmed, so the
    /// menu bar reads "Desk Mic" rather than "Logitech USB Headset H340".
    private func shortName(for deviceID: AudioDeviceID, in list: [AudioDevice], fallback: String) -> String? {
        guard let device = list.first(where: { $0.id == deviceID }) else { return nil }

        if let nickname = nicknames.nickname(for: device.name) {
            return nickname
        }

        var name = device.name
        let boilerplates = ["Microphone", "Mic", "Built-in", "Audio", "Device"]
        for word in boilerplates {
            name = name.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }

        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? fallback : name
    }
}
