import CoreAudio
import Foundation

/// A CoreAudio device as the system reports it.
struct HardwareDevice: Hashable, Sendable {
    let deviceID: AudioDeviceID
    let name: String
}

/// Single source of truth for CoreAudio hardware access.
///
/// Deliberately non-isolated and free of UI state, so App Intents (which the system
/// may run before any window exists) can enumerate and switch devices without going
/// through `AudioManager`. `AudioManager` builds its published state on top of these
/// primitives, so the UI path and the automation path cannot drift apart.
enum AudioHardware {

    // MARK: - Enumeration

    private static func systemDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }

        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
        ) == noErr else { return [] }
        return ids
    }

    private static func name(of deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        return name?.takeRetainedValue() as String? ?? "Unknown Device"
    }

    private static func hasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func devices(withStreamsIn scope: AudioObjectPropertyScope) -> [HardwareDevice] {
        systemDevices().compactMap { id in
            guard hasStreams(id, scope: scope) else { return nil }
            let deviceName = name(of: id)
            // CoreAudio's private aggregate that mirrors the default device — never user-facing.
            guard !deviceName.contains("CADefaultDeviceAggregate") else { return nil }
            return HardwareDevice(deviceID: id, name: deviceName)
        }
    }

    static func inputDevices() -> [HardwareDevice] {
        devices(withStreamsIn: kAudioObjectPropertyScopeInput)
    }

    static func outputDevices() -> [HardwareDevice] {
        devices(withStreamsIn: kAudioObjectPropertyScopeOutput)
    }

    static func inputDevice(withID deviceID: AudioDeviceID) -> HardwareDevice? {
        inputDevices().first { $0.deviceID == deviceID }
    }

    static func outputDevice(withID deviceID: AudioDeviceID) -> HardwareDevice? {
        outputDevices().first { $0.deviceID == deviceID }
    }

    // MARK: - Default device

    private static func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    private static func setDefaultDevice(_ selector: AudioObjectPropertySelector, to deviceID: AudioDeviceID) -> Bool {
        var id = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let err = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &id
        )
        return err == noErr
    }

    static func defaultInputID() -> AudioDeviceID {
        defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
    }

    static func defaultOutputID() -> AudioDeviceID {
        defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
    }

    @discardableResult
    static func setDefaultInput(_ deviceID: AudioDeviceID) -> Bool {
        setDefaultDevice(kAudioHardwarePropertyDefaultInputDevice, to: deviceID)
    }

    @discardableResult
    static func setDefaultOutput(_ deviceID: AudioDeviceID) -> Bool {
        setDefaultDevice(kAudioHardwarePropertyDefaultOutputDevice, to: deviceID)
    }

    // MARK: - Mute

    private static func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    /// Not every device exposes a hardware mute control; the UI hides the row when it doesn't.
    static func supportsMute(_ deviceID: AudioDeviceID) -> Bool {
        guard deviceID != kAudioObjectUnknown else { return false }
        var address = muteAddress()
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr
    }

    static func isMuted(_ deviceID: AudioDeviceID) -> Bool? {
        guard supportsMute(deviceID) else { return nil }
        var address = muteAddress()
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    @discardableResult
    static func setMuted(_ muted: Bool, on deviceID: AudioDeviceID) -> Bool {
        guard supportsMute(deviceID) else { return false }
        var address = muteAddress()
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        ) == noErr
    }

    // MARK: - Nicknames

    /// Custom aliases live in the same UserDefaults key the UI writes, so Siri resolves
    /// "studio mic" against the name Alan actually sees in the menu.
    static func nicknames() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: "deviceNicknames") as? [String: String] ?? [:]
    }

    /// The name a human would recognise: the nickname if one is set, otherwise the raw device name.
    static func displayName(for rawName: String) -> String {
        let alias = nicknames()[rawName]?.trimmingCharacters(in: .whitespaces)
        guard let alias, !alias.isEmpty else { return rawName }
        return alias
    }

    /// A raw device name with vendor boilerplate trimmed, so Pickr's own surfaces read
    /// "MacBook Pro" rather than "MacBook Pro Microphone".
    ///
    /// Nicknames are deliberately *not* applied here: the caller owns the nickname store and
    /// therefore the SwiftUI observation that makes a rename re-render. Callers compose the two.
    static func trimmedName(for rawName: String) -> String {
        var name = rawName
        for word in ["Microphone", "Mic", "Built-in", "Audio", "Device"] {
            name = name.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? rawName : name
    }
}
