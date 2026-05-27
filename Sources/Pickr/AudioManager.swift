import CoreAudio
import AVFoundation
import Foundation
import KeyboardShortcuts
import OSLog

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
}

@MainActor
class AudioManager: ObservableObject {
    @Published var devices: [AudioDevice] = []
    @Published var defaultDeviceID: AudioDeviceID = kAudioObjectUnknown
    @Published var outputDevices: [AudioDevice] = []
    @Published var defaultOutputDeviceID: AudioDeviceID = kAudioObjectUnknown
    @Published var isMuted: Bool = false
    @Published var inputLevel: Float = 0
    @Published var supportsMute: Bool = false

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var isMeteringActive = false
    private var recorderURL: URL?

    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var devicesListenerBlock: AudioObjectPropertyListenerBlock?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Pickr", category: "AudioManager")

    init() {
        refresh()
        startListening()
        KeyboardShortcuts.onKeyDown(for: .toggleMute) { [weak self] in
            self?.toggleMute()
        }
    }

    func refresh() {
        devices = fetchInputDevices()
        defaultDeviceID = fetchDefaultInputDevice()
        outputDevices = fetchOutputDevices()
        defaultOutputDeviceID = fetchDefaultOutputDevice()
        syncMuteState()
    }

    func setDefault(_ deviceID: AudioDeviceID) {
        var id = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let err = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &id
        )
        if err == noErr {
            defaultDeviceID = deviceID
            syncMuteState()
            restartRecorderIfActive()
        }
    }

    func setDefaultOutput(_ deviceID: AudioDeviceID) {
        var id = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let err = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &id
        )
        if err == noErr {
            defaultOutputDeviceID = deviceID
        }
    }

    func toggleMute() {
        guard supportsMute else { return }
        isMuted.toggle()
        applyMuteState()
        OSDController.shared.show(isMuted: isMuted)
    }

    // MARK: - Level Metering

    func startLevelMetering() {
        guard !isMeteringActive else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startRecorder()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted { DispatchQueue.main.async { self?.startRecorder() } }
            }
        default:
            break
        }
    }

    func stopLevelMetering() {
        guard isMeteringActive else { return }
        levelTimer?.invalidate()
        levelTimer = nil
        recorder?.stop()
        recorder = nil
        if let url = recorderURL { try? FileManager.default.removeItem(at: url) }
        recorderURL = nil
        isMeteringActive = false
        inputLevel = 0
    }

    /// Call when the default input device changes so the recorder follows the new device.
    private func restartRecorderIfActive() {
        guard isMeteringActive else { return }
        stopLevelMetering()
        startRecorder()
    }

    private func startRecorder() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pickr_meter_\(UUID().uuidString).caf")
        recorderURL = url

        let settings: [String: Any] = [
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVFormatIDKey: kAudioFormatAppleLossless,
        ]

        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else {
            logger.error("Failed to create AVAudioRecorder")
            return
        }
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec
        isMeteringActive = true

        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let rec = self.recorder else { return }
                rec.updateMeters()
                let dB = rec.averagePower(forChannel: 0)      // -160…0 dB
                self.inputLevel = Float((Double(dB) + 60.0) / 60.0).clamped(to: 0...1)
            }
        }
    }

    // MARK: - Mute

    private func applyMuteState() {
        guard defaultDeviceID != kAudioObjectUnknown, supportsMute else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = isMuted ? 1 : 0
        AudioObjectSetPropertyData(defaultDeviceID, &address, 0, nil,
                                   UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private func syncMuteState() {
        guard defaultDeviceID != kAudioObjectUnknown else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyDataSize(defaultDeviceID, &address, 0, nil, &size)
        supportsMute = (status == noErr)

        if supportsMute {
            var value: UInt32 = 0
            if AudioObjectGetPropertyData(defaultDeviceID, &address, 0, nil, &size, &value) == noErr {
                isMuted = value != 0
            }
        } else {
            isMuted = false
        }
    }

    // MARK: - CoreAudio Listeners

    private func startListening() {
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let defaultBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        self.defaultDeviceListenerBlock = defaultBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, nil, defaultBlock
        )

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, nil, defaultBlock
        )

        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let devicesBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        self.devicesListenerBlock = devicesBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &devicesAddress, nil, devicesBlock
        )
    }

    deinit {
        var defaultInputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if let block = defaultDeviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputAddress, nil, block)
        }

        var defaultOutputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if let block = defaultDeviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultOutputAddress, nil, block)
        }

        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if let block = devicesListenerBlock {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, nil, block)
        }

    }

    // MARK: - CoreAudio Helpers

    private func fetchDefaultInputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func fetchDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func fetchInputDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
        return ids.compactMap { id in
            guard hasInputStreams(id) else { return nil }
            let name = deviceName(id)
            guard !name.contains("CADefaultDeviceAggregate") else { return nil }
            return AudioDevice(id: id, name: name)
        }
    }

    private func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }

    private func fetchOutputDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: kAudioObjectUnknown, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids)
        return ids.compactMap { id in
            guard hasOutputStreams(id) else { return nil }
            let name = deviceName(id)
            guard !name.contains("CADefaultDeviceAggregate") else { return nil }
            return AudioDevice(id: id, name: name)
        }
    }

    private func hasOutputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr && size > 0
    }

    private func deviceName(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        return name?.takeRetainedValue() as String? ?? "Unknown Device"
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
