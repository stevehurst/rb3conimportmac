import Foundation
import SwiftUI

struct LibrarySong: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let header: STFSHeader
    let modificationDate: Date?
    var isSelected: Bool = false

    var songName: String { header.displayName }
    var artist: String { header.artist }
    var album: String { header.album }
    var fileSize: UInt64 { header.fileSize }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: LibrarySong, rhs: LibrarySong) -> Bool { lhs.id == rhs.id }
}

struct ArtistGroup: Identifiable {
    let id = UUID()
    let artist: String
    var songs: [LibrarySong]
}

struct DuplicateGroup: Identifiable, Equatable {
    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id && lhs.files.map(\.id) == rhs.files.map(\.id)
    }

    let id = UUID()
    let songName: String
    let artist: String
    var files: [LibrarySong]
}

private let libraryPathKey = "libraryFolderPath"

@MainActor
class LibraryManager: ObservableObject {
    @Published var artistGroups: [ArtistGroup] = []
    @Published var allSongs: [LibrarySong] = []
    @Published var isScanning = false
    @Published var libraryPath: String?
    @Published var duplicates: [DuplicateGroup] = []
    @Published var selectedSongIDs: Set<UUID> = []

    private var watchTask: Task<Void, Never>?
    private var lastScanFingerprint: String = ""

    init() {
        libraryPath = UserDefaults.standard.string(forKey: libraryPathKey)
        if libraryPath != nil {
            Task {
                await scan()
                startWatching()
            }
        }
    }

    deinit {
        watchTask?.cancel()
    }

    var selectedSongs: [LibrarySong] {
        allSongs.filter { selectedSongIDs.contains($0.id) }
    }

    func selectLibraryFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Library Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.watchTask?.cancel()
                self?.libraryPath = url.path
                UserDefaults.standard.set(url.path, forKey: libraryPathKey)
                await self?.scan()
                self?.startWatching()
            }
        }
    }

    // MARK: - File system watching

    private func startWatching() {
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                guard let self, let path = self.libraryPath else { return }
                let fingerprint = await Task.detached(priority: .utility) {
                    Self.folderFingerprint(URL(fileURLWithPath: path))
                }.value
                if fingerprint != self.lastScanFingerprint && !self.lastScanFingerprint.isEmpty {
                    await self.scan()
                }
            }
        }
    }

    private nonisolated static func folderFingerprint(_ folder: URL) -> String {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return "" }

        var parts: [String] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "rb3con" || ext == "" else { continue }
            guard let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                  res.isRegularFile == true else { continue }
            let size = res.fileSize ?? 0
            let mod = res.contentModificationDate?.timeIntervalSince1970 ?? 0
            parts.append("\(fileURL.lastPathComponent):\(size):\(mod)")
        }
        parts.sort()
        return parts.joined(separator: "|")
    }

    // MARK: - Scanning

    func scan() async {
        guard let path = libraryPath else { return }
        let folderURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }

        isScanning = true

        let (songs, fingerprint) = await Task.detached(priority: .userInitiated) {
            let s = Self.scanFolder(folderURL)
            let f = Self.folderFingerprint(folderURL)
            return (s, f)
        }.value

        let validIDs = Set(songs.map(\.id))
        selectedSongIDs = selectedSongIDs.intersection(validIDs)
        allSongs = songs
        lastScanFingerprint = fingerprint
        buildGroups()
        detectDuplicates()
        isScanning = false
    }

    private nonisolated static func scanFolder(_ folder: URL) -> [LibrarySong] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var songs: [LibrarySong] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "rb3con" || ext == "" else { continue }

            guard let res = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  res.isRegularFile == true else { continue }

            guard let header = try? parseSTFSHeader(from: fileURL),
                  header.isRB3 else { continue }

            songs.append(LibrarySong(
                id: UUID(),
                url: fileURL,
                header: header,
                modificationDate: res.contentModificationDate
            ))
        }
        return songs.sorted { $0.songName.localizedCaseInsensitiveCompare($1.songName) == .orderedAscending }
    }

    private func buildGroups() {
        let grouped = Dictionary(grouping: allSongs) { $0.artist }
        artistGroups = grouped.map { group in
            ArtistGroup(
                artist: group.key,
                songs: group.value.sorted { $0.songName.localizedCaseInsensitiveCompare($1.songName) == .orderedAscending }
            )
        }
        .sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
    }

    private func detectDuplicates() {
        let grouped = Dictionary(grouping: allSongs) {
            "\($0.songName.lowercased().trimmingCharacters(in: .whitespaces))|\($0.artist.lowercased().trimmingCharacters(in: .whitespaces))"
        }

        duplicates = grouped.compactMap { (_, songs) -> DuplicateGroup? in
            guard songs.count > 1 else { return nil }
            let sorted = songs.sorted { $0.fileSize > $1.fileSize }
            return DuplicateGroup(songName: sorted[0].songName, artist: sorted[0].artist, files: sorted)
        }
    }

    func resolveDuplicate(keep: UUID, remove: UUID) {
        guard let removeIdx = allSongs.firstIndex(where: { $0.id == remove }) else { return }
        let removeURL = allSongs[removeIdx].url
        try? FileManager.default.trashItem(at: removeURL, resultingItemURL: nil)
        allSongs.remove(at: removeIdx)
        selectedSongIDs.remove(remove)
        buildGroups()
        detectDuplicates()
    }

    func toggleSelection(_ id: UUID) {
        if selectedSongIDs.contains(id) {
            selectedSongIDs.remove(id)
        } else {
            selectedSongIDs.insert(id)
        }
    }

    func selectAll() {
        selectedSongIDs = Set(allSongs.map(\.id))
    }

    func deselectAll() {
        selectedSongIDs.removeAll()
    }

    func refreshSong(at url: URL) {
        guard let idx = allSongs.firstIndex(where: { $0.url == url }),
              let header = try? parseSTFSHeader(from: url) else { return }
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        allSongs[idx] = LibrarySong(id: allSongs[idx].id, url: url, header: header, modificationDate: modDate)
        buildGroups()
    }

    func addFiles(_ urls: [URL]) {
        guard let path = libraryPath else { return }
        let libraryURL = URL(fileURLWithPath: path)
        let fm = FileManager.default

        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ext == "rb3con" || ext == "" else { continue }
            let dest = libraryURL.appendingPathComponent(url.lastPathComponent)
            if !fm.fileExists(atPath: dest.path) {
                try? fm.copyItem(at: url, to: dest)
            }
        }

        Task { await scan() }
    }
}
