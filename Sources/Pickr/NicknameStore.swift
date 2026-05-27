import Foundation

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
}
