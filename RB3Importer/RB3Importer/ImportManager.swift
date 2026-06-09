import Foundation
import CryptoKit

enum SongStatus: Equatable {
    case pending
    case ready
    case copying
    case copied
    case skipped(String)
    case failed(String)

    var iconName: String {
        switch self {
        case .pending:  return "clock"
        case .ready:    return "checkmark.circle"
        case .copying:  return "arrow.right.circle"
        case .copied:   return "checkmark.circle.fill"
        case .skipped:  return "minus.circle"
        case .failed:   return "xmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .pending:          return "Pending"
        case .ready:            return "Ready"
        case .copying:          return "Copying…"
        case .copied:           return "Copied"
        case .skipped(let r):   return r
        case .failed(let e):    return e
        }
    }

    var isTerminal: Bool {
        switch self {
        case .copied, .skipped, .failed: return true
        default: return false
        }
    }
}

struct SongEntry: Identifiable {
    let id = UUID()
    let url: URL
    var header: STFSHeader?
    var status: SongStatus = .pending

    var filename: String { url.lastPathComponent }
    var displayName: String { header?.displayName ?? filename }
    var destFilename: String {
        let name = filename
        return name.count > 42 ? String(name.prefix(42)) : name
    }
}

private let rb3BasePath = "Content/0000000000000000/45410914"
private let contentCachePath = "Content/0000000000000000/FFFE07DF/00040000/ContentCache.pkg"

@MainActor
class ImportManager: ObservableObject {
    @Published var songs: [SongEntry] = []
    @Published var isImporting = false
    @Published var copied = 0
    @Published var skipped = 0
    @Published var errors = 0

    var readyCount: Int { songs.filter { $0.status == .ready }.count }

    // MARK: - File management

    func addFiles(_ urls: [URL]) {
        let deduped = urls.filter { url in !songs.contains { $0.url == url } }
        guard !deduped.isEmpty else { return }
        let entries = deduped.map { SongEntry(url: $0) }
        songs.append(contentsOf: entries)
        Task { await parseHeaders(ids: entries.map(\.id)) }
    }

    func remove(_ id: UUID) {
        songs.removeAll { $0.id == id }
    }

    func reset() {
        songs.removeAll()
        copied = 0; skipped = 0; errors = 0
    }

    // MARK: - Parsing

    private func parseHeaders(ids: [UUID]) async {
        for id in ids {
            guard let idx = songs.firstIndex(where: { $0.id == id }) else { continue }
            let url = songs[idx].url
            do {
                let header = try await Task.detached(priority: .userInitiated) {
                    try parseSTFSHeader(from: url)
                }.value
                songs[idx].header = header
                if !header.isRB3 {
                    songs[idx].status = .skipped("Not an RB3 package")
                } else if header.contentFolder == nil {
                    songs[idx].status = .skipped("Unknown content type \(String(format: "%08X", header.contentType))")
                } else {
                    songs[idx].status = .ready
                }
            } catch {
                songs[idx].status = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Import

    func importAll(to driveURL: URL) async {
        guard !isImporting else { return }
        isImporting = true
        copied = 0; skipped = 0; errors = 0

        var touchedDirs: Set<URL> = []

        for idx in songs.indices {
            let entry = songs[idx]
            guard entry.status == .ready, let header = entry.header,
                  let folder = header.contentFolder else {
                if case .skipped = entry.status { skipped += 1 }
                continue
            }

            let destDir = driveURL
                .appendingPathComponent(rb3BasePath)
                .appendingPathComponent(folder)
            let destFile = destDir.appendingPathComponent(entry.destFilename)

            // Skip if already present with matching size
            if FileManager.default.fileExists(atPath: destFile.path) {
                let srcSize = (try? entry.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
                let dstSize = (try? destFile.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -2
                if srcSize == dstSize {
                    songs[idx].status = .skipped("Already on drive")
                    skipped += 1
                    continue
                }
            }

            songs[idx].status = .copying

            do {
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                let data = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: entry.url)
                }.value

                try await Task.detached(priority: .userInitiated) {
                    try data.write(to: destFile, options: .atomic)
                }.value

                // Integrity check
                let written = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: destFile)
                }.value
                let srcHash = SHA256.hash(data: data)
                let dstHash = SHA256.hash(data: written)
                guard srcHash == dstHash else {
                    try? FileManager.default.removeItem(at: destFile)
                    throw ImportError.hashMismatch
                }

                songs[idx].status = .copied
                copied += 1
                touchedDirs.insert(destDir)
            } catch {
                songs[idx].status = .failed(error.localizedDescription)
                errors += 1
            }
        }

        for dir in touchedDirs { cleanAppleDouble(in: dir) }

        let cache = driveURL.appendingPathComponent(contentCachePath)
        try? FileManager.default.removeItem(at: cache)

        isImporting = false
    }

    private func cleanAppleDouble(in dir: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return }
        for url in contents where url.lastPathComponent.hasPrefix("._") {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum ImportError: LocalizedError {
    case hashMismatch
    var errorDescription: String? { "Integrity check failed — file may be corrupted on drive" }
}
