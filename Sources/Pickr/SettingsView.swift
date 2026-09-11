import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var isLaunchAtLoginEnabled = LoginItemManager.isEnabled
    @AppStorage("menuBarLabel") private var menuBarLabel: MenuBarLabelMode = .input
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
}
