import Foundation
import SwiftUI

class NicknameStore: ObservableObject {
    private let defaultsKey = "deviceNicknames"
    @Published private(set) var nicknames: [String: String]

    init() {
        nicknames = UserDefaults.standard.dictionary(forKey: "deviceNicknames") as? [String: String] ?? [:]
    }

    func nickname(for deviceName: String) -> String? {
        guard let n = nicknames[deviceName], !n.isEmpty else { return nil }
        return n
    }

    func setNickname(_ name: String, for deviceName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            nicknames.removeValue(forKey: deviceName)
        } else {
            nicknames[deviceName] = trimmed
        }
        UserDefaults.standard.set(nicknames, forKey: defaultsKey)
    }

    /// A field the user types straight into, with no confirm step. The panel's inline rename commits
    /// on Enter because the panel has somewhere to go; a Settings field has no such moment, so the
    /// edit itself has to be the save, and every surface that reads the name follows along.
    ///
    /// The typed value is stored exactly as it arrives rather than trimmed: trimming on each
    /// keystroke would delete the space between two words the instant it was typed, so "Office Mic"
    /// would come out as "OfficeMic". Presenters trim for display (`AudioHardware.displayName`).
    func binding(for deviceName: String) -> Binding<String> {
        Binding(
            get: { self.nicknames[deviceName] ?? "" },
            set: { typed in
                if typed.isEmpty {
                    self.nicknames.removeValue(forKey: deviceName)
                } else {
                    self.nicknames[deviceName] = typed
                }
                UserDefaults.standard.set(self.nicknames, forKey: self.defaultsKey)
            }
        )
    }
}
