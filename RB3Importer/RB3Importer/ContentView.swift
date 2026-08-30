import SwiftUI
import CryptoKit

private let contentCachePath = "Content/0000000000000000/FFFE07DF/00040000/ContentCache.pkg"

struct ContentView: View {
    @StateObject private var library = LibraryManager()
    @StateObject private var driveManager = DriveManager()
    @StateObject private var driveContent = DriveContentManager()
    @State private var selectedDriveID: String?
    @State private var selectedTab = 0
    @State private var syncStatus: SyncStatus = .idle

    private var selectedDrive: DriveInfo? {
        driveManager.drives.first { $0.id == selectedDriveID }
    }

    private var isSyncing: Bool {
        if case .syncing = syncStatus { return true }
        return false
    }

    var body: some View {
        mainContent
            .frame(minWidth: 700, minHeight: 520)
            .onAppear(perform: handleAppear)
            .onChange(of: driveManager.drives, handleDrivesChanged)
            .onChange(of: selectedDriveID, handleDriveSelected)
            .onChange(of: driveContent.driveSongs) { _, _ in autoSelectSyncedSongs() }
            .onChange(of: library.allSongs) { _, _ in autoSelectSyncedSongs() }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            syncBar
            Divider()
            tabContent
        }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            LibraryView(library: library, driveContent: driveContent, onSyncNow: handleSyncNow)
                .tabItem { Label("Library", systemImage: "music.note.list") }
                .tag(0)

            DriveView(library: library, driveContent: driveContent, selectedDrive: selectedDrive, onRemove: handleRemoveFromDrive)
                .tabItem { Label("Drive", systemImage: "externaldrive.fill") }
                .tag(1)
        }
    }

    private var syncBar: some View {
        HStack(spacing: 10) {
            // Drive picker
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedDriveID) {
                Text("Select Xbox 360 USB drive…").tag(nil as String?)
                if !driveManager.drives.isEmpty {
                    Divider()
                    ForEach(driveManager.drives) { drive in
                        HStack {
                            Text(drive.displayName)
                            if drive.hasXboxContent {
                                Image(systemName: "gamecontroller.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .tag(drive.id as String?)
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: 300)

            Button {
                let currentDriveURL = selectedDrive?.url
                driveManager.refresh()
                if let url = currentDriveURL {
                    Task { await driveContent.scan(driveURL: url) }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Rescan drives and drive content")

            if let drive = selectedDrive {
                if drive.hasXboxContent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .help("No Xbox Content folder — configure this drive on your Xbox 360 first")
                }
            }

            if driveContent.isScanning {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Scanning drive…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Some scanning takes time, be patient.")
                            .font(.caption2)
                            .italic()
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Sync status
            syncStatusView

            // Sync button
            Button {
                guard let drive = selectedDrive else { return }
                Task { await syncToDrive(drive.url) }
            } label: {
                if isSyncing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6)
                        Text("Syncing…")
                    }
                    .frame(minWidth: 100)
                } else {
                    Label("Sync to Drive", systemImage: "arrow.right.circle")
                        .frame(minWidth: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedDrive == nil || library.selectedSongs.isEmpty || isSyncing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var syncStatusView: some View {
        if isSyncing, case .syncing(let copied, let total) = syncStatus {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.6)
                Text("Syncing \(copied)/\(total)…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            liveSyncCounts
        }
    }

    @ViewBuilder
    private var liveSyncCounts: some View {
        let onDrive = library.selectedSongs.filter { driveContent.isSongOnDrive($0) && !driveContent.songNeedsResync($0) }.count
        let needsResync = library.selectedSongs.filter { driveContent.songNeedsResync($0) }.count
        let pending = library.selectedSongs.count - onDrive - needsResync

        if library.selectedSongs.isEmpty {
            Text("No songs selected")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            HStack(spacing: 6) {
                if onDrive > 0 {
                    Label("\(onDrive) on drive", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
                if needsResync > 0 {
                    Label("\(needsResync) updated", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.blue)
                }
                if pending > 0 {
                    Label("\(pending) pending", systemImage: "arrow.right.circle.dotted")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
        }
    }

    private func handleAppear() {
        driveManager.refresh()
    }

    private func handleDrivesChanged(_: [DriveInfo], _ drives: [DriveInfo]) {
        if selectedDriveID == nil {
            let xbox = drives.filter { $0.hasXboxContent }
            if xbox.count == 1 {
                selectedDriveID = xbox[0].id
            }
        } else if let drive = drives.first(where: { $0.id == selectedDriveID }) {
            Task { await driveContent.scan(driveURL: drive.url) }
        }
    }

    private func handleDriveSelected(_: String?, _ newID: String?) {
        if let newID, let drive = driveManager.drives.first(where: { $0.id == newID }) {
            Task { await driveContent.scan(driveURL: drive.url) }
        } else {
            driveContent.driveSongs = []
        }
    }

    private func autoSelectSyncedSongs() {
        for song in library.allSongs where driveContent.isSongOnDrive(song) {
            library.selectedSongIDs.insert(song.id)
        }
    }

    private func handleRemoveFromDrive(_ driveSong: DriveSong) {
        driveContent.removeFromDrive(driveSong)
        // Deselect the matching library song
        if let libSong = library.allSongs.first(where: {
            $0.url.lastPathComponent.lowercased() == driveSong.filename.lowercased() ||
            $0.songName.lowercased() == driveSong.displayName.lowercased()
        }) {
            library.selectedSongIDs.remove(libSong.id)
        }
    }

    private func handleSyncNow(_ song: LibrarySong) {
        guard let drive = selectedDrive else { return }
        Task { await syncSongs([song], to: drive.url, skipped: 0) }
    }

    private func syncToDrive(_ driveURL: URL) async {
        let songsToSync = library.selectedSongs.filter {
            !driveContent.isSongOnDrive($0) || driveContent.songNeedsResync($0)
        }

        if !songsToSync.isEmpty {
            await syncSongs(songsToSync, to: driveURL, skipped: library.selectedSongs.count - songsToSync.count)
        }

        let contentRoot = driveURL.appendingPathComponent("Content")
        cleanDriveMetadataFiles(under: contentRoot)
        let cache = driveURL.appendingPathComponent(contentCachePath)
        try? FileManager.default.removeItem(at: cache)

        await driveContent.scan(driveURL: driveURL)

        if songsToSync.isEmpty {
            syncStatus = .done(copied: 0, skipped: library.selectedSongs.count, errors: 0)
        }
    }

    private func syncSongs(_ songsToSync: [LibrarySong], to driveURL: URL, skipped initialSkipped: Int) async {
        guard !songsToSync.isEmpty else {
            syncStatus = .done(copied: 0, skipped: initialSkipped, errors: 0)
            return
        }

        var copied = 0
        let skipped = initialSkipped
        var errors = 0
        let total = songsToSync.count
        syncStatus = .syncing(copied: 0, total: total)

        for song in songsToSync {
            let destDir = driveURL
                .appendingPathComponent(song.game.syncBasePath)
                .appendingPathComponent("00000001")
            let destName = song.url.lastPathComponent.count > 42
                ? String(song.url.lastPathComponent.prefix(42))
                : song.url.lastPathComponent
            let destFile = destDir.appendingPathComponent(destName)

            do {
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destFile.path) {
                    try FileManager.default.removeItem(at: destFile)
                }
                let data = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: song.url)
                }.value
                try await Task.detached(priority: .userInitiated) {
                    try data.write(to: destFile)
                }.value
                let written = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: destFile)
                }.value
                guard SHA256.hash(data: data) == SHA256.hash(data: written) else {
                    try? FileManager.default.removeItem(at: destFile)
                    errors += 1
                    continue
                }
                copied += 1
                syncStatus = .syncing(copied: copied, total: total)
            } catch {
                errors += 1
            }
        }

        syncStatus = .done(copied: copied, skipped: skipped, errors: errors)
    }
}

private func cleanDriveMetadataFiles(under root: URL) {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: []) else { return }
    for case let url as URL in enumerator {
        let name = url.lastPathComponent
        if name.hasPrefix("._") || name == ".DS_Store" || name == ".Spotlight-V100" || name == ".Trashes" || name == ".fseventsd" {
            try? fm.removeItem(at: url)
        }
    }
}
