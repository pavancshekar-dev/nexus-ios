import Foundation
import Observation
import SwiftUI

@Observable
final class ModelDownloadManager: NSObject {
    var progress: [String: Double] = [:]
    var downloadedModels: Set<String> = []
    var activeDownloads: [String: URLSessionDownloadTask] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var progressHandlers: [Int: String] = [:] // taskId -> modelFile
    private var completionHandlers: [Int: CheckedContinuation<URL, Error>] = [:]

    static var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override init() {
        super.init()
        loadDownloadedModels()
    }

    // MARK: - Public

    func download(model: MobileModel, serverUrl: String) async throws {
        let filename = model.file
        guard activeDownloads[filename] == nil else { return }

        progress[filename] = 0.0

        let urlString = "\(serverUrl)/api/quantization/download?file=\(filename)"
        guard let url = URL(string: urlString) else {
            throw NexusError.downloadFailed("Invalid URL")
        }

        let localURL: URL = try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url)
            let taskId = task.taskIdentifier
            progressHandlers[taskId] = filename
            completionHandlers[taskId] = continuation
            activeDownloads[filename] = task
            task.resume()
        }

        // Move to models directory
        let destination = Self.modelsDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: localURL, to: destination)

        await MainActor.run {
            self.downloadedModels.insert(filename)
            self.progress.removeValue(forKey: filename)
            self.activeDownloads.removeValue(forKey: filename)
        }

        saveDownloadedModels()
    }

    func cancelDownload(for filename: String) {
        activeDownloads[filename]?.cancel()
        activeDownloads.removeValue(forKey: filename)
        progress.removeValue(forKey: filename)
    }

    func deleteModel(filename: String) {
        let path = Self.modelsDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: path)
        downloadedModels.remove(filename)
        saveDownloadedModels()
    }

    func modelPath(for filename: String) -> String? {
        let path = Self.modelsDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return path.path
    }

    func isDownloaded(_ filename: String) -> Bool {
        downloadedModels.contains(filename)
    }

    // MARK: - Persistence

    private func loadDownloadedModels() {
        let stored = UserDefaults.standard.stringArray(forKey: "downloadedModels") ?? []
        downloadedModels = Set(stored.filter { filename in
            let path = Self.modelsDirectory.appendingPathComponent(filename)
            return FileManager.default.fileExists(atPath: path.path)
        })
    }

    private func saveDownloadedModels() {
        UserDefaults.standard.set(Array(downloadedModels), forKey: "downloadedModels")
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadManager: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskId = downloadTask.taskIdentifier
        if let continuation = completionHandlers.removeValue(forKey: taskId) {
            progressHandlers.removeValue(forKey: taskId)
            continuation.resume(returning: location)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskId = downloadTask.taskIdentifier
        guard let filename = progressHandlers[taskId],
              totalBytesExpectedToWrite > 0
        else { return }

        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.progress[filename] = pct
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let taskId = task.taskIdentifier
        if let error = error,
           let continuation = completionHandlers.removeValue(forKey: taskId) {
            let filename = progressHandlers.removeValue(forKey: taskId)
            continuation.resume(throwing: error)
            if let filename {
                Task { @MainActor in
                    self.activeDownloads.removeValue(forKey: filename)
                    self.progress.removeValue(forKey: filename)
                }
            }
        }
    }
}
