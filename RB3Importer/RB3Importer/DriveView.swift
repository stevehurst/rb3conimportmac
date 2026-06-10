import SwiftUI

struct DriveSong: Identifiable, Equatable {
    static func == (lhs: DriveSong, rhs: DriveSong) -> Bool { lhs.id == rhs.id }
    let id = UUID()
    let url: URL
    let header: STFSHeader?
    let filename: String

    var displayName: String { header?.displayName ?? filename }
    var artist: String { header?.artist ?? "Unknown Artist" }
    var album: String { header?.album ?? "" }
}

@MainActor
class DriveContentManager: ObservableObject {
    @Published var driveSongs: [DriveSong] = []
    @Published var isScanning = false

    func scan(driveURL: URL) async {
        isScanning = true

        let conFolder = driveURL
            .appendingPathComponent("Content/0000000000000000/45410914/00000001")

        let songs = await Task.detached(priority: .userInitiated) { () -> [DriveSong] in
            let fm = FileManager.default
            guard fm.fileExists(atPath: conFolder.path),
                  let files = try? fm.contentsOfDirectory(at: conFolder, includingPropertiesForKeys: nil) else {
                return []
            }

            return files.compactMap { url -> DriveSong? in
                guard !url.lastPathComponent.hasPrefix(".") else { return nil }
                let header = try? parseSTFSHeader(from: url)
                return DriveSong(url: url, header: header, filename: url.lastPathComponent)
            }
        }.value

        driveSongs = songs.sorted {
            let artistCmp = $0.artist.localizedCaseInsensitiveCompare($1.artist)
            if artistCmp != .orderedSame { return artistCmp == .orderedAscending }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        isScanning = false
    }

    func removeFromDrive(_ song: DriveSong) {
        try? FileManager.default.removeItem(at: song.url)
        driveSongs.removeAll { $0.id == song.id }
    }

    func isSongOnDrive(_ librarySong: LibrarySong) -> Bool {
        matchingDriveSong(for: librarySong) != nil
    }

    func songNeedsResync(_ librarySong: LibrarySong) -> Bool {
        guard let driveSong = matchingDriveSong(for: librarySong) else { return false }
        let driveSize = driveSong.header?.fileSize ?? 0
        return librarySong.fileSize != driveSize
    }

    func matchingDriveSong(for librarySong: LibrarySong) -> DriveSong? {
        let libFilename = librarySong.url.lastPathComponent.lowercased()
        let libName = librarySong.songName.lowercased()
        return driveSongs.first { driveSong in
            driveSong.filename.lowercased() == libFilename ||
            driveSong.displayName.lowercased() == libName
        }
    }
}

enum SyncStatus {
    case idle
    case syncing(copied: Int, total: Int)
    case done(copied: Int, skipped: Int, errors: Int)
}

struct DriveView: View {
    @ObservedObject var library: LibraryManager
    @ObservedObject var driveContent: DriveContentManager
    let selectedDrive: DriveInfo?

    var body: some View {
        if selectedDrive == nil {
            VStack(spacing: 14) {
                Image(systemName: "externaldrive.badge.questionmark")
                    .font(.system(size: 52))
                    .foregroundStyle(.tertiary)
                Text("No Drive Selected")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Plug in your Xbox 360 USB drive and select it above")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if driveContent.isScanning {
            VStack(spacing: 14) {
                ProgressView()
                Text("Scanning drive…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            driveContentList
        }
    }

    private var driveContentList: some View {
        List {
            if !library.selectedSongs.isEmpty {
                Section {
                    ForEach(library.selectedSongs) { song in
                        SyncSongRow(song: song, driveContent: driveContent)
                    }
                } header: {
                    let pending = library.selectedSongs.filter { !driveContent.isSongOnDrive($0) }.count
                    Text("Selected for Sync — \(pending) pending, \(library.selectedSongs.count - pending) already on drive")
                }
            }

            Section("On Drive (\(driveContent.driveSongs.count) songs)") {
                if driveContent.driveSongs.isEmpty {
                    Text("No songs on drive yet")
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(driveContent.driveSongs) { song in
                        HStack(spacing: 10) {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(song.displayName)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(song.artist)
                                    if !song.album.isEmpty {
                                        Text("·")
                                        Text(song.album)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                driveContent.removeFromDrive(song)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Remove from drive")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct SyncSongRow: View {
    let song: LibrarySong
    @ObservedObject var driveContent: DriveContentManager

    private var onDrive: Bool { driveContent.isSongOnDrive(song) }
    private var needsResync: Bool { driveContent.songNeedsResync(song) }

    private var statusLabel: String {
        if needsResync { return "Updated" }
        if onDrive { return "On Drive" }
        return "Pending Sync"
    }

    private var statusColor: Color {
        if needsResync { return .blue }
        if onDrive { return .green }
        return .orange
    }

    private var statusIcon: String {
        if needsResync { return "arrow.triangle.2.circlepath" }
        if onDrive { return "checkmark.circle.fill" }
        return "arrow.right.circle.dotted"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.songName)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(statusLabel)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(statusColor)
        }
    }
}
