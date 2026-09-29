import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var isLaunchAtLoginEnabled = LoginItemManager.isEnabled
    @AppStorage("menuBarLabel") private var menuBarLabel: MenuBarLabelMode = .input
    @EnvironmentObject private var audio: AudioManager
    @EnvironmentObject private var nicknames: NicknameStore
    private let appStoreID = "6761876281"

    var body: some View {
        // The Settings scene sizes the window to the content's frame, and a bare Form does not
        // scroll on overflow — with content taller than the frame it simply clipped (no scroll
        // bar, no resize affordance). ScrollView + a fixed frame makes the pane scroll properly.
        ScrollView {
            Form {
            Section {
                HStack {
                    Text("Toggle Mute")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleMute)
                }

                HStack {
                    Text("Next Input")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .nextInput)
                }

                HStack {
                    Text("Next Output")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .nextOutput)
                }

                Toggle("Launch at Login", isOn: Binding(
                    get: { isLaunchAtLoginEnabled },
                    set: {
                        LoginItemManager.isEnabled = $0
                        isLaunchAtLoginEnabled = LoginItemManager.isEnabled
                    }
                ))
                .padding(.top, 8)

            } header: {
                Text("System Control")
            } footer: {
                Text("These shortcuts act system-wide. Cycle through your devices without opening the menu, or mute your active microphone from any application.\n\nPickr also works with Siri and the Shortcuts app, so you can switch devices or toggle mute from a voice command or an automation.")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }

            Section {
                // Hand-rolled label row rather than `Picker("Show", …)`: a titled Picker in a
                // macOS Form renders its label outside the content column, which left it visibly
                // left of the labels in the sections above.
                HStack {
                    Text("Show")
                    Spacer()
                    Picker("", selection: $menuBarLabel) {
                        ForEach(MenuBarLabelMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

            } header: {
                Text("Menu Bar")
            } footer: {
                Text("The glyph always reflects whether your microphone is muted. Naming the device beside it is also the only confirmation you get when a shortcut or a Siri phrase changes it.")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }

            Section {
                // The panel heads its two lists INPUT and OUTPUT, so a device can be found here by
                // the same name it carries there. Every visible device gets a row, in the order the
                // panel lists them, so this reads as the same list rather than a second opinion.
                deviceGroupLabel("INPUT")
                if audio.devices.isEmpty {
                    emptyGroupLabel("No input devices found")
                } else {
                    ForEach(audio.devices) { device in
                        DeviceNameRow(device: device, symbol: "mic", nicknames: nicknames)
                    }
                }

                deviceGroupLabel("OUTPUT")
                if audio.outputDevices.isEmpty {
                    emptyGroupLabel("No output devices found")
                } else {
                    ForEach(audio.outputDevices) { device in
                        DeviceNameRow(device: device, symbol: "speaker.wave.2", nicknames: nicknames)
                    }
                }

            } header: {
                Text("Device Names")
            } footer: {
                Text("Hardware names are long and often unreadable. Type a name you recognise and Pickr uses it everywhere — the panel, the menu bar, and Siri. Clear the field to go back to the hardware name.\n\nA device that appears in both lists — a headset, say — keeps one name, so renaming it in either place renames it in both.")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }

            Section {
                HStack {
                    Text("Email Feedback")
                    Spacer()
                    Button("Contact Support") {
                        if let url = URL(string: "mailto:alan@fractals.sg") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                HStack {
                    Text("Rate Pickr")
                    Spacer()
                    Button("Leave a Review") {
                        if let url = URL(string: "macappstore://itunes.apple.com/app/id\(appStoreID)?action=write-review") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                HStack {
                    Text("Website")
                    Spacer()
                    Button("Visit Fractals") {
                        if let url = URL(string: "https://fractals.sg") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("Support & About")
            }

            VStack(spacing: 4) {
                Text("Fractals Collective. Made in Aldinga, 2026")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 16)
            }
            .padding(24)
        }
        // Fixed, deliberate pane size: content taller than this scrolls (above), which is the
        // behaviour users expect from System Settings-style panes.
        .frame(width: 500, height: 560)
    }

    private func deviceGroupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }

    private func emptyGroupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Device Name Row

/// One device and the name it should answer to.
///
/// Renaming used to live only behind a pencil that appeared on hover in the panel, which meant the
/// feature was present but effectively undiscoverable. This is the visible home for it; the panel's
/// inline pencil and right-click menu are shortcuts to the same store.
private struct DeviceNameRow: View {
    let device: AudioDevice
    let symbol: String
    @ObservedObject var nicknames: NicknameStore

    private var isRenamed: Bool { nicknames.nickname(for: device.name) != nil }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(isRenamed ? Color.accentColor : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                TextField(
                    "",
                    text: nicknames.binding(for: device.name),
                    prompt: Text(AudioHardware.trimmedName(for: device.name))
                )
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

                // Shown only once a custom name is hiding the hardware name, which is the one
                // moment the raw name is not already on screen.
                if isRenamed {
                    Text(device.name)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Built only when it applies, never stacked at zero opacity: a view at `.opacity(0)`
            // still receives hits, which is what put an invisible control over every panel row in
            // the 1.1 cycle.
            if isRenamed {
                Button {
                    nicknames.setNickname("", for: device.name)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Go back to the hardware name")
            }
        }
    }
}
