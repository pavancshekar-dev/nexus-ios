import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class ModelDownloadManager {
    var progress: [String: Double] = [:]
    var downloadedModels: Set<String> = []
    var activeDownloads: [String: URLSessionDownloadTask] = [:]

    @ObservationIgnored
    private var progressHandlers: [Int: String] = [:] // taskId -> modelFile
    @ObservationIgnored
    private var completionHandlers: [Int: CheckedContinuation<URL, Error>] = [:]

    @ObservationIgnored
    private var session: URLSession!
    @ObservationIgnored
    private var sessionDelegate: DownloadSessionDelegate!

    static var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        sessionDelegate = DownloadSessionDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600
        session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        sessionDelegate.onFinished = { [weak self] taskId, tempLocation in
            // Copy file immediately on delegate queue (system deletes original after return)
            let safeCopy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            try? FileManager.default.copyItem(at: tempLocation, to: safeCopy)
            Task { @MainActor [weak self] in
                self?.handleDownloadFinished(taskId: taskId, location: safeCopy)
            }
        }
        sessionDelegate.onProgress = { [weak self] taskId, fraction in
            Task { @MainActor [weak self] in
                self?.handleProgress(taskId: taskId, fraction: fraction)
            }
        }
        sessionDelegate.onError = { [weak self] taskId, error in
            Task { @MainActor [weak self] in
                self?.handleDownloadError(taskId: taskId, error: error)
            }
        }

        loadDownloadedModels()
    }

    // MARK: - Delegate Handlers

    private func handleDownloadFinished(taskId: Int, location: URL) {
        if let continuation = completionHandlers.removeValue(forKey: taskId) {
            progressHandlers.removeValue(forKey: taskId)
            continuation.resume(returning: location)
        }
    }

    private func handleProgress(taskId: Int, fraction: Double) {
        guard let filename = progressHandlers[taskId] else { return }
        progress[filename] = fraction
    }

    private func handleDownloadError(taskId: Int, error: Error) {
        if let continuation = completionHandlers.removeValue(forKey: taskId) {
            let filename = progressHandlers.removeValue(forKey: taskId)
            continuation.resume(throwing: error)
            if let filename {
                activeDownloads.removeValue(forKey: filename)
                progress.removeValue(forKey: filename)
            }
        }
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

        downloadedModels.insert(filename)
        progress.removeValue(forKey: filename)
        activeDownloads.removeValue(forKey: filename)

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

// MARK: - URLSession Delegate (separate from @Observable class)

private final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var onFinished: (@Sendable (Int, URL) -> Void)?
    var onProgress: (@Sendable (Int, Double) -> Void)?
    var onError: (@Sendable (Int, Error) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        onFinished?(downloadTask.taskIdentifier, location)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress?(downloadTask.taskIdentifier, pct)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            onError?(task.taskIdentifier, error)
        }
    }
}
