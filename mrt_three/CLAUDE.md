# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a modern SwiftUI macOS application for recording meetings with advanced audio capture capabilities. The project follows Clean Architecture principles with SOLID design patterns, featuring dual audio capture (microphone + system audio) and sophisticated audio processing.

## Build and Development Commands

### Building the Project
```bash
# Install dependencies
swift package resolve

# Build the project
swift build

# Run the application
swift run MacOSApp
```

### Development Tools
```bash
# Install SwiftLint (if not already installed)
brew install swiftlint

# Run SwiftLint
swiftlint

# Run tests
xcodebuild clean test -scheme "MacOSApp" -destination "platform=macOS"

# Run with pretty output
xcodebuild clean test -scheme "MacOSApp" -destination "platform=macOS" | xcpretty
```

### Environment Setup
```bash
# Initial environment setup
chmod +x setup_environment.sh
./setup_environment.sh
```

## Architecture

The application follows **Clean Architecture** with these key layers:

### Core Components
- **AudioRecordingCoordinator**: Central orchestrator managing all audio services
- **Specialized Services**: Each service has a single responsibility
  - `MicrophoneCaptureService`: Microphone audio capture  
  - `SystemAudioCaptureService`: System audio capture via ScreenCaptureKit
  - `CoreAudioTapService`: **NEW** Real system audio capture via XPC + Helper Tool
  - `AudioFileService`: Thread-safe file operations and audio mixing
  - `UnifiedAudioConverter`: Single audio conversion service (replaces 3 duplicates)
  - `LoggingService`: Structured logging with categories (centralized)
  - `DiagnosticsService`: Performance monitoring
  - `SimpleTranscriptionEngine`: Single transcription engine
  - `ExportService`: Centralized export functionality
- **XPC Architecture**: **NEW** Helper Tool privilegiada para Core Audio TAP
  - `CoreAudioTapXPCService`: Cliente XPC para comunicação com Helper Tool
  - `HelperInstallationManager`: Gerenciamento automático da Helper Tool
  - `AudioCaptureHelper`: Ferramenta privilegiada para captura real do sistema
- **Protocol-First Design**: All services implement protocols for testability
- **Single Responsibility**: Each service has one clear purpose, no wrapper services

### Architecture Layers
1. **Views Layer** (`Sources/Views/`): SwiftUI views and components
2. **ViewModels** (`Sources/ViewModels/`): `MeetingStore` is the single state manager
3. **Coordinator Layer** (`Sources/Services/Recording/`): Orchestrates multiple services
4. **Services Layer** (`Sources/Services/`): Specialized business logic services
5. **Core Layer** (`Sources/Core/`): Protocols, models, extensions with unified utilities

### Key Technical Features
- **Dual Audio Capture**: Simultaneous microphone + system audio recording
- **ScreenCaptureKit Integration**: macOS 13+ system audio capture
- **Audio Synchronization**: Intelligent timing and format conversion
- **Unified Audio Processing**: Single converter handles M4A→WAV with multiple strategies
- **Warmup System**: 3-second stabilization before recording
- **Performance Monitoring**: Buffer analysis and diagnostics
- **Transcription Pipeline**: Automated speech-to-text with SherpaONNX backend

## Core Audio TAP Architecture (NEW)

### Overview
The application now includes a **real system audio capture solution** using Core Audio TAP via a privileged Helper Tool and XPC communication, replacing the previous experimental implementation.

### Components
1. **CoreAudioTapService.swift** - Main service implementing `SystemAudioCaptureProtocol`
2. **CoreAudioTapXPCService.swift** - XPC client for communication with Helper Tool
3. **HelperInstallationManager.swift** - Manages Helper Tool installation and verification
4. **AudioCaptureHelper** (Objective-C) - Privileged Helper Tool executable
5. **AudioHelperProtocol.h** - XPC protocol definition

### Key Features
- **Real System Audio Capture**: Actual system audio (not ScreenCaptureKit simulation)
- **Automatic Installation**: Helper Tool installed via SMJobBless when needed
- **Secure Communication**: XPC protocol with client validation
- **Fallback Support**: Graceful degradation to ScreenCaptureKit if Helper Tool fails
- **macOS 13+ Support**: Lower requirement than original Core Audio TAP APIs

### Usage Flow
1. User enables "Core Audio TAP" in settings
2. `MeetingStore.useCoreAudioTap` triggers strategy change
3. `AudioRecordingCoordinator` switches to `.coreAudioTaps` strategy
4. `CoreAudioTapService` checks Helper Tool status
5. If needed, `HelperInstallationManager` installs Helper Tool automatically
6. XPC communication established for real audio capture

### Development Notes
- Helper Tool source located in `/HelperTools/AudioCaptureHelper/`
- XPC protocols defined in `/Sources/Services/Audio/XPC/`
- Integration maintains compatibility with existing audio architecture
- All logging uses `LoggingService.shared` with `.audio` category

## Coding Standards

### Language Conventions (Bilingual Approach)
- **Code** (classes, methods, variables): **English**
- **UI Strings**: **Portuguese** 
- **Comments**: **Portuguese**
- **Logs**: **English**

### Naming Conventions
- Services: End with "Service" (e.g., `AudioFileService`)
- ViewModels: Use "Store" or "Coordinator" (e.g., `MeetingStore`)
- Views: End with "View" (e.g., `MeetingDetailView`)
- Protocols: End with "Protocol" (e.g., `AudioCaptureProtocol`)

### Service Structure Pattern
```swift
class ExampleService {
    // MARK: - Public Methods
    
    // MARK: - Configuration
    
    // MARK: - Private Helpers
    
    // MARK: - Event Handlers
}
```

### Error Handling Pattern
```swift
do {
    try performOperation()
    logger.info("Operation completed successfully")
} catch {
    logger.error("Operation failed", error: error, category: .audio)
    throw ServiceError.operationFailed(error)
}
```

## Key Development Patterns

### Dependency Injection
All services use constructor injection:
```swift
init(
    audioFileManager: AudioFileManagerProtocol,
    permissionManager: AudioPermissionManager,
    logger: LoggingService = .shared
) {
    self.audioFileManager = audioFileManager
    self.permissionManager = permissionManager
    self.logger = logger
}
```

### Reactive State Management
Uses Combine framework with `@Published` properties:
```swift
@Published var isRecording = false
@Published var currentDuration: TimeInterval = 0
@Published var audioLevel: Float = 0
```

### Logging Categories
```swift
enum LogCategory: String {
    case general = "General"
    case audio = "Audio"
    case recording = "Recording"
    case file = "File"
    case performance = "Performance"
    case diagnostics = "Diagnostics"
}
```

## Anti-Duplication Guidelines

**CRITICAL**: Before implementing any functionality, check if it already exists. The codebase has been extensively refactored to eliminate duplications.

### Unified Components - DO NOT DUPLICATE
1. **Audio Conversion**: Use only `UnifiedAudioConverter` (supports AVFoundation + FFmpeg strategies)
2. **Logging**: Use only `LoggingService.shared` - NEVER use print() statements
3. **Time Formatting**: Use `TimeInterval+Format` extensions (mmssFormat, adaptiveFormat, readableFormat)
4. **Export Operations**: Use only `ExportService.shared` for all file exports
5. **Audio Visualization**: Use `AudioLevelVisualizerView` for all audio level displays
6. **State Management**: Use only `MeetingStore` - RecordingViewModel was eliminated
7. **Transcription**: Use only `SimpleTranscriptionEngine` - TranscriptionEngine was eliminated

### Before Adding New Services
1. **Check Existing Services**: Search codebase for similar functionality
2. **Extend vs Create**: Prefer extending existing services over creating new ones
3. **Protocol First**: Define interfaces before implementation
4. **Single Responsibility**: Each service should have one clear purpose
5. **No Wrapper Services**: Avoid services that just delegate to other services

### Common Duplication Patterns to Avoid
- **Time Formatting**: Use TimeInterval extensions, not local formatting functions
- **File Operations**: Use AudioFileManager/AudioFileService, not direct FileManager calls
- **Logging**: Use LoggingService categories, not custom logging implementations
- **Audio Processing**: Use UnifiedAudioConverter, not separate converters
- **State Management**: Use MeetingStore computed properties, not duplicate ViewModels

## Requirements

- **macOS 13+**: Minimum deployment target for ScreenCaptureKit
- **Xcode**: Swift Package Manager project
- **SwiftLint**: For code style enforcement
- **No external dependencies**: Pure Swift/SwiftUI implementation

## Important Implementation Notes

### Audio Permissions
The app requires both microphone and screen recording permissions. Use `AudioPermissionManager` for all permission handling.

### Thread Safety
- Audio operations use dedicated dispatch queues
- UI updates must be on main thread via `@MainActor`
- File operations are thread-safe through `AudioFileService`

### Performance Considerations
- Use `DiagnosticsService` for monitoring critical operations
- Audio buffers are monitored for optimal performance
- Warmup system ensures stable recording quality

### Testing Strategy
- All services implement protocols for easy mocking
- Use dependency injection for testable components
- Coordinator pattern enables isolated unit testing

## Common Development Tasks

### Adding New Audio Capture Capabilities
1. Check if similar functionality exists in existing capture services
2. Create protocol first (e.g., `BluetoothAudioCaptureProtocol`)
3. Implement service following naming conventions
4. Integrate into `AudioRecordingCoordinator`
5. Add logging via `LoggingService.shared` with appropriate categories
6. Add performance monitoring via `DiagnosticsService`
7. Update UI through `MeetingStore` computed properties

### Adding Audio Processing Features
- **ALWAYS** use `UnifiedAudioConverter` - never create separate converters
- Use existing `AudioConfiguration` system for settings
- Monitor performance through `DiagnosticsService`
- Ensure thread safety for file operations via `AudioFileService`
- Test with various audio formats and sample rates

### Adding UI Components
- Check `Sources/Views/Components/` for existing reusable components
- Use `AudioLevelVisualizerView` for any audio visualization needs
- Use `TimeInterval+Format` extensions for time display
- Get state from `MeetingStore` - never create wrapper ViewModels
- Use `ExportService.shared` for any export functionality

### Adding New Transcription Features
- Extend `SimpleTranscriptionEngine` - don't create new engines
- Use `TranscriptionManager` for queue management
- Follow existing transcription workflow patterns
- Add progress tracking via existing callback mechanisms