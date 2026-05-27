import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var isLaunchAtLoginEnabled = LoginItemManager.isEnabled
    private let appStoreID = "6761876281"

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle Mute")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleMute)
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
                Text("Pickr's global shortcut acts system-wide. You can mute your active microphone natively from any application without opening the menu.")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
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
        .frame(width: 450, height: 350)
    }
}
