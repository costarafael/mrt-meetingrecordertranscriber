import Foundation
import AVFoundation

protocol AudioFileServiceProtocol {
    func createAudioFile(
        for meetingId: UUID,
        configuration: AudioConfiguration,
        type: AudioFileType
    ) throws -> AVAudioFile
    
    func cleanupTemporaryFiles(for meetingId: UUID)
    
    func getAudioDirectory() -> URL
    
    func fileExists(at path: String) -> Bool
    
    func getFileSize(at path: String) -> UInt64?
    
    func getAudioDuration(at path: String) -> TimeInterval?
    
    func listAudioFiles(for meetingId: UUID?) -> [AudioFileInfo]
    
    func finalizeFiles() async
}