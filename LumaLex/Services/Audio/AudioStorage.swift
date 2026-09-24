import AVFoundation
import Foundation

enum AudioStorage {
    static var directory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("Audio", isDirectory: true)
    }

    static func url(for relativePath: String) -> URL {
        directory.appendingPathComponent(relativePath, isDirectory: false)
    }

    static func importAudio(from source: URL) async throws -> (path: String, duration: TimeInterval) {
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = UUID().uuidString + "." + source.pathExtension.lowercased()
        let destination = url(for: filename)
        try FileManager.default.copyItem(at: source, to: destination)
        do {
            let duration = try await AVURLAsset(url: destination).load(.duration).seconds
            guard duration.isFinite, duration > 0 else { throw AudioStorageError.invalidAudio }
            return (filename, duration)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    static func readTranscript(from source: URL) throws -> String {
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        return try String(contentsOf: source, encoding: .utf8)
    }
}

enum AudioStorageError: LocalizedError {
    case invalidAudio

    var errorDescription: String? { "This audio file could not be played." }
}

