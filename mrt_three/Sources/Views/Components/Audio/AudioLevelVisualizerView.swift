import SwiftUI

// MARK: - Unified Audio Visualization Component

struct AudioLevelVisualizerView: View {
    let level: Float
    let configuration: VisualizerConfiguration
    
    init(level: Float, configuration: VisualizerConfiguration = .default) {
        self.level = level
        self.configuration = configuration
    }
    
    var body: some View {
        switch configuration.style {
        case .waveform:
            WaveformVisualizerView(
                progress: Double(level),
                configuration: configuration
            )
        case .levelBar:
            LevelBarVisualizerView(
                level: level,
                configuration: configuration
            )
        case .spectrum:
            SpectrumVisualizerView(
                level: level,
                configuration: configuration
            )
        }
    }
}

// MARK: - Configuration

struct VisualizerConfiguration {
    let barCount: Int
    let spacing: CGFloat
    let style: VisualizerStyle
    let primaryColor: Color
    let secondaryColor: Color
    let animationDuration: Double
    let height: CGFloat
    let cornerRadius: CGFloat
    
    enum VisualizerStyle {
        case waveform      // Para reprodução de áudio
        case levelBar      // Para níveis em tempo real
        case spectrum      // Para análise de frequência
    }
    
    static let `default` = VisualizerConfiguration(
        barCount: 50,
        spacing: 2,
        style: .levelBar,
        primaryColor: .blue,
        secondaryColor: Color.gray.opacity(0.3),
        animationDuration: 0.1,
        height: 20,
        cornerRadius: 5
    )
    
    static let waveformPlayback = VisualizerConfiguration(
        barCount: 50,
        spacing: 2,
        style: .waveform,
        primaryColor: .blue,
        secondaryColor: Color.gray.opacity(0.3),
        animationDuration: 0.1,
        height: 50,
        cornerRadius: 2
    )
    
    static let recordingLevel = VisualizerConfiguration(
        barCount: 1,
        spacing: 0,
        style: .levelBar,
        primaryColor: .green,
        secondaryColor: Color.gray.opacity(0.3),
        animationDuration: 0.05,
        height: 20,
        cornerRadius: 5
    )
    
    static let spectrumAnalysis = VisualizerConfiguration(
        barCount: 30,
        spacing: 1,
        style: .spectrum,
        primaryColor: .orange,
        secondaryColor: Color.gray.opacity(0.2),
        animationDuration: 0.08,
        height: 40,
        cornerRadius: 1
    )
}

// MARK: - Waveform Style (for audio playback)

struct WaveformVisualizerView: View {
    let progress: Double
    let configuration: VisualizerConfiguration
    
    var body: some View {
        HStack(spacing: configuration.spacing) {
            ForEach(0..<configuration.barCount, id: \.self) { index in
                Rectangle()
                    .fill(index < Int(progress * Double(configuration.barCount)) ? 
                          configuration.primaryColor : configuration.secondaryColor)
                    .frame(width: 3, height: randomHeight())
                    .cornerRadius(configuration.cornerRadius)
                    .animation(.easeInOut(duration: configuration.animationDuration), value: progress)
            }
        }
        .frame(height: configuration.height)
    }
    
    private func randomHeight() -> CGFloat {
        // Create consistent pseudo-random heights based on bar position
        CGFloat.random(in: (configuration.height * 0.2)...(configuration.height * 0.9))
    }
}

// MARK: - Level Bar Style (for real-time audio levels)

struct LevelBarVisualizerView: View {
    let level: Float
    let configuration: VisualizerConfiguration
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(configuration.secondaryColor)
                    .cornerRadius(configuration.cornerRadius)
                
                // Level indicator
                Rectangle()
                    .fill(levelColor)
                    .frame(width: CGFloat(level) * geometry.size.width)
                    .cornerRadius(configuration.cornerRadius)
                    .animation(.easeInOut(duration: configuration.animationDuration), value: level)
            }
        }
        .frame(height: configuration.height)
    }
    
    private var levelColor: Color {
        if level > 0.8 {
            return .red
        } else if level > 0.6 {
            return .orange
        } else if level > 0.3 {
            return .yellow
        } else {
            return configuration.primaryColor
        }
    }
}

// MARK: - Spectrum Style (for frequency analysis)

struct SpectrumVisualizerView: View {
    let level: Float
    let configuration: VisualizerConfiguration
    
    var body: some View {
        HStack(spacing: configuration.spacing) {
            ForEach(0..<configuration.barCount, id: \.self) { index in
                Rectangle()
                    .fill(configuration.primaryColor.opacity(barOpacity(for: index)))
                    .frame(width: barWidth, height: barHeight(for: index))
                    .cornerRadius(configuration.cornerRadius)
                    .animation(.easeInOut(duration: configuration.animationDuration), value: level)
            }
        }
        .frame(height: configuration.height)
    }
    
    private var barWidth: CGFloat {
        max(1, (configuration.height - configuration.spacing * CGFloat(configuration.barCount - 1)) / CGFloat(configuration.barCount))
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let normalizedIndex = Double(index) / Double(configuration.barCount - 1)
        let heightMultiplier = sin(normalizedIndex * .pi) * Double(level)
        return configuration.height * CGFloat(heightMultiplier)
    }
    
    private func barOpacity(for index: Int) -> Double {
        let normalizedIndex = Double(index) / Double(configuration.barCount - 1)
        return 0.3 + (0.7 * Double(level) * sin(normalizedIndex * .pi))
    }
}

// MARK: - Convenience Extensions

extension AudioLevelVisualizerView {
    /// Create a waveform visualizer for audio playback
    static func waveform(progress: Double) -> some View {
        AudioLevelVisualizerView(
            level: Float(progress),
            configuration: .waveformPlayback
        )
    }
    
    /// Create a level bar for recording
    static func recordingLevel(_ level: Float) -> some View {
        AudioLevelVisualizerView(
            level: level,
            configuration: .recordingLevel
        )
    }
    
    /// Create a spectrum analyzer
    static func spectrum(level: Float) -> some View {
        AudioLevelVisualizerView(
            level: level,
            configuration: .spectrumAnalysis
        )
    }
}

// MARK: - Previews

#Preview("Level Bar") {
    VStack(spacing: 20) {
        AudioLevelVisualizerView.recordingLevel(0.3)
        AudioLevelVisualizerView.recordingLevel(0.6)
        AudioLevelVisualizerView.recordingLevel(0.9)
    }
    .padding()
}

#Preview("Waveform") {
    VStack(spacing: 20) {
        AudioLevelVisualizerView.waveform(progress: 0.3)
        AudioLevelVisualizerView.waveform(progress: 0.6)
        AudioLevelVisualizerView.waveform(progress: 0.9)
    }
    .padding()
}

#Preview("Spectrum") {
    VStack(spacing: 20) {
        AudioLevelVisualizerView.spectrum(level: 0.3)
        AudioLevelVisualizerView.spectrum(level: 0.6)
        AudioLevelVisualizerView.spectrum(level: 0.9)
    }
    .padding()
}