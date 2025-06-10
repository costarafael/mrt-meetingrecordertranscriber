import SwiftUI
import Foundation

class RecordingViewModel: ObservableObject {
    // MARK: - Properties
    
    private let coordinator: AudioRecordingCoordinator
    private let formatter = DateComponentsFormatter()
    
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var isWarmingUp: Bool = false
    @Published var warmupProgress: Double = 0.0
    @Published var warmupCountdown: Int = 3
    @Published var durationText: String = "00:00"
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String?
    
    @Published var availableDevices: [AudioDevice] = []
    @Published var selectedDevice: AudioDevice?
    
    @Published var systemAudioEnabled: Bool = true
    @Published var systemAudioAvailable: Bool = false
    
    // MARK: - Initialization
    
    init(coordinator: AudioRecordingCoordinator) {
        self.coordinator = coordinator
        setupFormatter()
        setupBindings()
    }
    
    private func setupFormatter() {
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
    }
    
    private func setupBindings() {
        coordinator.$isRecording
            .assign(to: &$isRecording)
        
        coordinator.$isPaused
            .assign(to: &$isPaused)
        
        coordinator.$isWarmingUp
            .assign(to: &$isWarmingUp)
        
        coordinator.$warmupProgress
            .assign(to: &$warmupProgress)
        
        coordinator.$warmupCountdown
            .assign(to: &$warmupCountdown)
        
        coordinator.$audioLevel
            .assign(to: &$audioLevel)
        
        coordinator.$errorMessage
            .assign(to: &$errorMessage)
        
        coordinator.$currentDuration
            .map { [weak self] duration in
                self?.formatDuration(duration) ?? "00:00"
            }
            .assign(to: &$durationText)
        
        coordinator.$availableInputDevices
            .assign(to: &$availableDevices)
        
        coordinator.$selectedInputDevice
            .assign(to: &$selectedDevice)
        
        coordinator.$systemAudioEnabled
            .assign(to: &$systemAudioEnabled)
        
        coordinator.$systemAudioAvailable
            .assign(to: &$systemAudioAvailable)
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        return formatter.string(from: duration) ?? "00:00"
    }
    
    // MARK: - User Actions
    
    func startRecording(for meeting: Meeting) {
        Task {
            await coordinator.startRecording(for: meeting)
        }
    }
    
    func pauseRecording() {
        coordinator.pauseRecording()
    }
    
    func resumeRecording() {
        coordinator.resumeRecording()
    }
    
    func stopRecording() async -> (audioPath: String?, duration: TimeInterval) {
        return await coordinator.stopRecording()
    }
    
    func selectDevice(_ device: AudioDevice) {
        coordinator.selectInputDevice(device)
    }
    
    func setSystemAudioEnabled(_ enabled: Bool) {
        coordinator.setSystemAudioEnabled(enabled)
    }
    
    func refreshDevices() {
        coordinator.loadAvailableDevices()
    }
} 