import ServiceManagement
import OSLog

enum LoginItemManager {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Pickr", category: "LoginItemManager")

    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                logger.error("Launch at login error: \(String(describing: error))")
            }
        }
    }
}
