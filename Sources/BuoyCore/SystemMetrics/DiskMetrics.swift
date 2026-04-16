import Darwin
import Foundation

public enum DiskMetricsCollector {
    public static func sample(mountPoint: String = "/") -> DiskSnapshot {
        if let snapshot = sampleUsingVolumeMetadata(mountPoint: mountPoint) {
            return snapshot
        }

        var stats = statfs()
        guard statfs(mountPoint, &stats) == 0 else {
            return .empty
        }
        let blockSize = UInt64(stats.f_bsize)
        let total = UInt64(stats.f_blocks) * blockSize
        let free = UInt64(stats.f_bfree) * blockSize
        let avail = UInt64(stats.f_bavail) * blockSize
        let used = total > free ? total - free : 0

        let gb = 1_073_741_824.0
        let totalGB = Double(total) / gb
        let usedGB = Double(used) / gb
        let availGB = Double(avail) / gb
        let percent = total > 0 ? (Double(used) / Double(total)) * 100.0 : 0

        return DiskSnapshot(
            totalGB: totalGB,
            usedGB: usedGB,
            availableGB: availGB,
            usagePercent: percent,
            mountPoint: mountPoint
        )
    }

    private static func sampleUsingVolumeMetadata(mountPoint: String) -> DiskSnapshot? {
        let url = URL(fileURLWithPath: mountPoint, isDirectory: true)
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity,
              total > 0 else {
            return nil
        }

        let totalBytes = Int64(total)
        let availableBytes = Int64(max(0, available))
        let usedBytes = max(0, totalBytes - availableBytes)
        let gb = 1_073_741_824.0

        return DiskSnapshot(
            totalGB: Double(totalBytes) / gb,
            usedGB: Double(usedBytes) / gb,
            availableGB: Double(availableBytes) / gb,
            usagePercent: Double(usedBytes) / Double(totalBytes) * 100.0,
            mountPoint: mountPoint
        )
    }
}
