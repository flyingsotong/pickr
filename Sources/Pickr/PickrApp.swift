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
            HStack(spacing: 4) {
                Image(systemName: audio.isMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundStyle(audio.isMuted ? Color.red : Color.primary)
                if let name = shortName {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 100)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    /// Returns a short, readable name for the current device.
    private var shortName: String? {
        guard let device = audio.devices.first(where: { $0.id == audio.defaultDeviceID }) else { return nil }
        
        if let nickname = nicknames.nickname(for: device.name) {
            return nickname
        }
        
        var name = device.name
        let boilerplates = ["Microphone", "Mic", "Built-in", "Audio", "Device"]
        for word in boilerplates {
            name = name.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Mic" : name
    }
}
