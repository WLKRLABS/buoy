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
        let avail = UInt64(stats.f_bavail) * blockSize
        let used = total > avail ? total - avail : 0

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
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity else {
            return nil
        }

        return snapshotFromVolumeValues(
            totalBytes: Int64(total),
            availableBytes: values.volumeAvailableCapacity.map { Int64(max(0, $0)) },
            importantAvailableBytes: values.volumeAvailableCapacityForImportantUsage.map { Int64(max(0, $0)) },
            mountPoint: mountPoint
        )
    }

    static func snapshotFromVolumeValues(
        totalBytes: Int64,
        availableBytes: Int64?,
        importantAvailableBytes: Int64?,
        mountPoint: String
    ) -> DiskSnapshot? {
        guard totalBytes > 0 else { return nil }

        let preferredAvailableBytes = max(
            0,
            importantAvailableBytes ?? availableBytes ?? 0
        )
        let usedBytes = max(0, totalBytes - preferredAvailableBytes)
        let gb = 1_073_741_824.0

        return DiskSnapshot(
            totalGB: Double(totalBytes) / gb,
            usedGB: Double(usedBytes) / gb,
            availableGB: Double(preferredAvailableBytes) / gb,
            usagePercent: Double(usedBytes) / Double(totalBytes) * 100.0,
            mountPoint: mountPoint
        )
    }
}
