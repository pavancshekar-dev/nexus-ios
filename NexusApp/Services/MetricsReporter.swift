import Foundation
import Darwin
import Observation
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
final class MetricsReporter {
    var latestMetrics = SystemMetrics(cpuUsage: 0, memoryUsage: 0, temperature: 0, batteryLevel: 100)
    var totalInferences: Int = 0
    var totalTokens: Int = 0
    var lastTokensPerSec: Double = 0.0

    private var reportTask: Task<Void, Never>?
    private var apiClient: NexusAPIClient?

    func configure(apiClient: NexusAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Lifecycle

    func startReporting(serverUrl: String, deviceId: String) {
        stopReporting()

        reportTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.collectAndReport(serverUrl: serverUrl, deviceId: deviceId)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stopReporting() {
        reportTask?.cancel()
        reportTask = nil
    }

    func recordInference(
        tokensPerSec: Double,
        tokenCount: Int,
        elapsed: Double,
        activeModel: String,
        inferenceMode: InferenceMode,
        serverUrl: String,
        deviceId: String
    ) {
        totalInferences += 1
        totalTokens += tokenCount
        lastTokensPerSec = tokensPerSec

        // Persist
        UserDefaults.standard.set(totalInferences, forKey: "totalInferences")
        UserDefaults.standard.set(totalTokens, forKey: "totalTokens")

        // Report to server
        guard let apiClient else { return }
        Task {
            let payload = InferenceMetricsPayload(
                deviceId: deviceId,
                type: "inference_metrics",
                data: InferenceMetrics(
                    tokensPerSec: tokensPerSec,
                    tokenCount: tokenCount,
                    elapsed: elapsed,
                    memoryUsage: latestMetrics.memoryUsage,
                    cpuUsage: latestMetrics.cpuUsage,
                    batteryLevel: latestMetrics.batteryLevel,
                    activeModel: activeModel,
                    inferenceMode: inferenceMode.rawValue,
                    engineType: "Swift",
                    timestamp: Int64(Date().timeIntervalSince1970 * 1000)
                )
            )
            try? await apiClient.reportInferenceMetrics(serverUrl: serverUrl, payload: payload)
        }
    }

    // MARK: - Collection

    private func collectAndReport(serverUrl: String, deviceId: String) async {
        guard let apiClient else { return }
        collectMetrics()

        let payload = MetricsUpdatePayload(
            deviceId: deviceId,
            type: "metrics_update",
            data: MetricsUpdateData(
                cpuUsage: latestMetrics.cpuUsage,
                memoryUsage: latestMetrics.memoryUsage,
                temperature: latestMetrics.temperature,
                batteryLevel: latestMetrics.batteryLevel,
                tokensPerSec: lastTokensPerSec,
                activeModel: "",
                totalInferences: totalInferences,
                totalTokens: totalTokens,
                engineType: "Swift"
            )
        )

        try? await apiClient.reportMetrics(serverUrl: serverUrl, payload: payload)
    }

    private func collectMetrics() {
        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let totalMem = ProcessInfo.processInfo.physicalMemory
            let usedMem = UInt64(info.resident_size)
            latestMetrics.memoryUsage = Int(usedMem * 100 / totalMem)
        }

        // CPU usage (approximate via thread info)
        latestMetrics.cpuUsage = getCPUUsage()

        // Battery
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        latestMetrics.batteryLevel = level >= 0 ? Int(level * 100) : 100
        #else
        latestMetrics.batteryLevel = 100
        #endif

        // Temperature (not directly available on iOS, estimate)
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .nominal: latestMetrics.temperature = 35
        case .fair: latestMetrics.temperature = 45
        case .serious: latestMetrics.temperature = 55
        case .critical: latestMetrics.temperature = 65
        @unknown default: latestMetrics.temperature = 40
        }

        // Restore persisted totals
        totalInferences = UserDefaults.standard.integer(forKey: "totalInferences")
        totalTokens = UserDefaults.standard.integer(forKey: "totalTokens")
    }

    private func getCPUUsage() -> Int {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)

        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else { return 0 }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: threads),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            )
        }

        var totalUsage: Double = 0
        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var infoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
            let kr = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }
            if kr == KERN_SUCCESS && threadInfo.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
            }
        }

        return min(Int(totalUsage), 100)
    }
}
