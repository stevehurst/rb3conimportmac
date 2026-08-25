import Foundation

struct DriveInfo: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let totalBytes: Int64
    let freeBytes: Int64

    var displayName: String {
        let gb = Double(totalBytes) / 1_073_741_824
        return "\(name)  (\(String(format: "%.0f", gb)) GB)"
    }

    var hasXboxContent: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.appendingPathComponent("Content").path)
    }

    var detectedGames: [RockBandGame] {
        let fm = FileManager.default
        return RockBandGame.allCases.filter { game in
            fm.fileExists(atPath: url.appendingPathComponent(game.basePath).path)
        }
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
            .volumeIsInternalKey,
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
                  (res.volumeIsRemovable == true || res.volumeIsEjectable == true || res.volumeIsInternal == false),
                  let name = res.volumeName, !name.isEmpty
            else { return nil }

            return DriveInfo(
                id: url.path,
                url: url,
                name: name,
                totalBytes: Int64(res.volumeTotalCapacity ?? 0),
                freeBytes: Int64(res.volumeAvailableCapacity ?? 0)
            )
        }
    }
}
