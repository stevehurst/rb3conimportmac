import Foundation

struct DriveInfo: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let totalBytes: Int64
    let freeBytes: Int64

    var displayName: String {
        let gb = Double(totalBytes) / 1_073_741_824
        return "\(name)  (\(String(format: "%.0f", gb)) GB)"
    }

    var hasXboxContent: Bool {
        FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Content").path
        )
    }
}

@MainActor
class DriveManager: ObservableObject {
    @Published var drives: [DriveInfo] = []

    func refresh() {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: .skipHiddenVolumes
        ) else {
            drives = []
            return
        }

        drives = urls.compactMap { url -> DriveInfo? in
            guard let res = try? url.resourceValues(forKeys: keys),
                  (res.volumeIsRemovable == true || res.volumeIsEjectable == true),
                  let name = res.volumeName, !name.isEmpty
            else { return nil }

            return DriveInfo(
                id: UUID(),
                url: url,
                name: name,
                totalBytes: Int64(res.volumeTotalCapacity ?? 0),
                freeBytes: Int64(res.volumeAvailableCapacity ?? 0)
            )
        }
    }
}
