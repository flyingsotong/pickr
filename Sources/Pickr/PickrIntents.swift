import AppIntents
import CoreAudio
import Foundation

// MARK: - Entities
//
// Two entity types rather than one, because an input and an output can share a
// physical device and App Intents resolves a query type per entity. Keeping them
// separate means "switch input to X" and "switch output to X" can never be
// ambiguous to Siri.

struct PickrInputDevice: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Audio Input"
    static let defaultQuery = PickrInputDeviceQuery()

    let id: String
    let name: String
    let deviceID: AudioDeviceID

    init(hardware: HardwareDevice) {
        self.deviceID = hardware.deviceID
        self.id = "in-\(hardware.deviceID)"
        self.name = AudioHardware.displayName(for: hardware.name)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct PickrOutputDevice: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Audio Output"
    static let defaultQuery = PickrOutputDeviceQuery()

    let id: String
    let name: String
    let deviceID: AudioDeviceID

    init(hardware: HardwareDevice) {
        self.deviceID = hardware.deviceID
        self.id = "out-\(hardware.deviceID)"
        self.name = AudioHardware.displayName(for: hardware.name)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - Queries

struct PickrInputDeviceQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [PickrInputDevice] {
        let devices = AudioHardware.inputDevices().map(PickrInputDevice.init(hardware:))
        return devices.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PickrInputDevice] {
        let needle = string.lowercased()
        return AudioHardware.inputDevices()
            .filter { $0.name.lowercased().contains(needle) || AudioHardware.displayName(for: $0.name).lowercased().contains(needle) }
            .map(PickrInputDevice.init(hardware:))
    }

    func suggestedEntities() async throws -> [PickrInputDevice] {
        AudioHardware.inputDevices().map(PickrInputDevice.init(hardware:))
    }
}

struct PickrOutputDeviceQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [PickrOutputDevice] {
        let devices = AudioHardware.outputDevices().map(PickrOutputDevice.init(hardware:))
        return devices.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PickrOutputDevice] {
        let needle = string.lowercased()
        return AudioHardware.outputDevices()
            .filter { $0.name.lowercased().contains(needle) || AudioHardware.displayName(for: $0.name).lowercased().contains(needle) }
            .map(PickrOutputDevice.init(hardware:))
    }

    func suggestedEntities() async throws -> [PickrOutputDevice] {
        AudioHardware.outputDevices().map(PickrOutputDevice.init(hardware:))
    }
}

// MARK: - Intents

/// Routes the default microphone to a specific device.
struct SetInputDeviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Audio Input"
    static var description = IntentDescription(
        "Sets the Mac's default microphone to an input device Pickr knows about."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Input Device")
    var device: PickrInputDevice

    init() {}

    init(device: PickrInputDevice) {
        self.device = device
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let target = device
        let switched = await MainActor.run { () -> Bool in
            // Re-resolve at run time: the device may have been unplugged since it was chosen.
            guard let live = AudioHardware.inputDevice(withID: target.deviceID) else { return false }
            AudioManager.shared.setDefault(live.deviceID)
            return AudioHardware.defaultInputID() == live.deviceID
        }
        if switched {
            return .result(dialog: "Input is now \(target.name).")
        }
        return .result(dialog: "\(target.name) isn't connected right now.")
    }
}

/// Routes the default output to a specific device.
struct SetOutputDeviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Audio Output"
    static var description = IntentDescription(
        "Sets the Mac's default speaker or headphones to an output device Pickr knows about."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Output Device")
    var device: PickrOutputDevice

    init() {}

    init(device: PickrOutputDevice) {
        self.device = device
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let target = device
        let switched = await MainActor.run { () -> Bool in
            guard let live = AudioHardware.outputDevice(withID: target.deviceID) else { return false }
            AudioManager.shared.setDefaultOutput(live.deviceID)
            return AudioHardware.defaultOutputID() == live.deviceID
        }
        if switched {
            return .result(dialog: "Output is now \(target.name).")
        }
        return .result(dialog: "\(target.name) isn't connected right now.")
    }
}

/// Toggles the hardware mute on the current default microphone.
struct ToggleMuteIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Microphone Mute"
    static var description = IntentDescription(
        "Mutes or unmutes the current default microphone, the same way Pickr's global shortcut does."
    )
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await MainActor.run { () -> String in
            let manager = AudioManager.shared
            guard manager.supportsMute else {
                return "This microphone has no hardware mute control."
            }
            manager.toggleMute()
            return manager.isMuted ? "Microphone muted." : "Microphone unmuted."
        }
        return .result(dialog: IntentDialog(stringLiteral: result))
    }
}

// MARK: - Siri phrases

/// Exactly one `AppShortcutsProvider` for the app — more than one is a build-time error.
struct PickrAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleMuteIntent(),
            phrases: [
                "Toggle my mic in \(.applicationName)",
                "Mute my microphone in \(.applicationName)",
            ],
            shortTitle: "Toggle Mic Mute",
            systemImageName: "mic.slash"
        )
        AppShortcut(
            intent: SetInputDeviceIntent(),
            phrases: [
                "Switch input to \(\.$device) in \(.applicationName)",
            ],
            shortTitle: "Switch Audio Input",
            systemImageName: "mic"
        )
        AppShortcut(
            intent: SetOutputDeviceIntent(),
            phrases: [
                "Switch output to \(\.$device) in \(.applicationName)",
            ],
            shortTitle: "Switch Audio Output",
            systemImageName: "speaker.wave.2"
        )
    }
}
