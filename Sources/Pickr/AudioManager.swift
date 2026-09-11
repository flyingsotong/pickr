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
    /// One instance shared by the menu bar UI and by App Intents. The system may run an
    /// intent launched headlessly, so the intent path must reach the same object the
    /// panel renders from — otherwise Siri would switch the device and the UI would lie.
    static let shared = AudioManager()

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
        KeyboardShortcuts.onKeyDown(for: .nextInput) { [weak self] in
            self?.selectNextInput()
        }
        KeyboardShortcuts.onKeyDown(for: .nextOutput) { [weak self] in
            self?.selectNextOutput()
        }
    }

    func refresh() {
        devices = AudioHardware.inputDevices().map { AudioDevice(id: $0.deviceID, name: $0.name) }
        outputDevices = AudioHardware.outputDevices().map { AudioDevice(id: $0.deviceID, name: $0.name) }
        defaultDeviceID = AudioHardware.defaultInputID()
        defaultOutputDeviceID = AudioHardware.defaultOutputID()
        syncMuteState()
    }

    func setDefault(_ deviceID: AudioDeviceID) {
        if AudioHardware.setDefaultInput(deviceID) {
            defaultDeviceID = deviceID
            syncMuteState()
            restartRecorderIfActive()
        }
    }

    func setDefaultOutput(_ deviceID: AudioDeviceID) {
        if AudioHardware.setDefaultOutput(deviceID) {
            defaultOutputDeviceID = deviceID
        }
    }

    func toggleMute() {
        guard supportsMute else { return }
        isMuted.toggle()
        applyMuteState()
        OSDController.shared.show(isMuted: isMuted)
    }

    // MARK: - Cycling

    /// Cycle to the next device in the list, wrapping at the end. A hotkey has no visible target to
    /// aim at, so wrapping is the least surprising behaviour and the menu bar label is the feedback.
    func selectNextInput() {
        if let next = Self.device(after: defaultDeviceID, in: devices) {
            setDefault(next)
        }
    }

    func selectNextOutput() {
        if let next = Self.device(after: defaultOutputDeviceID, in: outputDevices) {
            setDefaultOutput(next)
        }
    }

    /// The device after `current`, or the first one when `current` is no longer in the list —
    /// which happens between a device being unplugged and the next refresh.
    private static func device(after current: AudioDeviceID, in list: [AudioDevice]) -> AudioDeviceID? {
        guard !list.isEmpty else { return nil }
        guard let index = list.firstIndex(where: { $0.id == current }) else { return list.first?.id }
        return list[(index + 1) % list.count].id
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
        AudioHardware.setMuted(isMuted, on: defaultDeviceID)
    }

    private func syncMuteState() {
        guard defaultDeviceID != kAudioObjectUnknown else { return }
        supportsMute = AudioHardware.supportsMute(defaultDeviceID)
        isMuted = supportsMute ? (AudioHardware.isMuted(defaultDeviceID) ?? false) : false
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
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
