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
                deviceLabel(for: audio.defaultDeviceID, in: audio.devices)
            case .output:
                deviceLabel(for: audio.defaultOutputDeviceID, in: audio.outputDevices)
            }
        }
    }

    @ViewBuilder
    private func deviceLabel(for deviceID: AudioDeviceID, in list: [AudioDevice]) -> some View {
        if let device = list.first(where: { $0.id == deviceID }) {
            Text(nicknames.nickname(for: device.name) ?? AudioHardware.trimmedName(for: device.name))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 100)
        }
    }
}
