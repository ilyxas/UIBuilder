// Copyright © 2025 Apple Inc.

import Foundation
import MLX

@MainActor @Observable final class DeviceStat: @unchecked Sendable {

    
    var gpuUsage = Memory.snapshot()

    private let initialGPUSnapshot = Memory.snapshot()
    nonisolated(unsafe) private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateGPUUsages()
            }
        }
    }

    nonisolated deinit {
        timer?.invalidate()
    }

    private func updateGPUUsages() {
        let gpuSnapshotDelta = initialGPUSnapshot.delta(Memory.snapshot())
        self.gpuUsage = gpuSnapshotDelta
    }

}
