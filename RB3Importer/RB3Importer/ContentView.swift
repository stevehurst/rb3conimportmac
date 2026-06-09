import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var importManager = ImportManager()
    @StateObject private var driveManager = DriveManager()
    @State private var selectedDriveID: UUID?
    @State private var isTargeted = false

    private var selectedDrive: DriveInfo? {
        driveManager.drives.first { $0.id == selectedDriveID }
    }

    var body: some View {
        VStack(spacing: 0) {
            driveBar
            Divider()
            dropZone
            Divider()
            bottomBar
        }
        .frame(minWidth: 600, minHeight: 440)
        .onAppear { driveManager.refresh() }
        .onChange(of: driveManager.drives) { _, drives in
            // Auto-select the only Xbox drive if there's exactly one
            if selectedDriveID == nil {
                let xbox = drives.filter { $0.hasXboxContent }
                if xbox.count == 1 { selectedDriveID = xbox[0].id }
            }
        }
    }

    // MARK: - Drive bar

    var driveBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedDriveID) {
                Text("Select Xbox 360 USB drive…").tag(nil as UUID?)
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
                        .tag(drive.id as UUID?)
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: 320)

            Button {
                driveManager.refresh()
                // Re-attempt auto-select after refresh
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let xbox = driveManager.drives.filter { $0.hasXboxContent }
                    if xbox.count == 1 { selectedDriveID = xbox[0].id }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh drive list")

            if let drive = selectedDrive {
                if drive.hasXboxContent {
                    Label("Xbox Content found", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("No Xbox Content folder", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help("Configure this drive on your Xbox 360 first to create the Content folder")
                }
            }

            Spacer()

            if !importManager.songs.isEmpty {
                Button("Clear") {
                    importManager.reset()
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Drop zone

    var dropZone: some View {
        ZStack {
            if importManager.songs.isEmpty {
                emptyState
            } else {
                songList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
                .padding(4)
        )
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("Drop .rb3con files here")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Custom Rock Band 3 CON packages for Xbox 360")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Button("Add Files…") { openFilePicker() }
                .padding(.top, 4)
        }
    }

    var songList: some View {
        List {
            ForEach(importManager.songs) { song in
                SongRow(song: song) { importManager.remove(song.id) }
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            Button("Add Files…") { openFilePicker() }
                .padding(12)
        }
    }

    // MARK: - Bottom bar

    var bottomBar: some View {
        HStack(spacing: 16) {
            statsView
            Spacer()
            importButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder var statsView: some View {
        if importManager.copied > 0 || importManager.errors > 0 || importManager.skipped > 0 {
            HStack(spacing: 12) {
                if importManager.copied > 0 {
                    Label("\(importManager.copied) copied", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if importManager.skipped > 0 {
                    Label("\(importManager.skipped) skipped", systemImage: "minus.circle")
                        .foregroundStyle(.secondary)
                }
                if importManager.errors > 0 {
                    Label("\(importManager.errors) failed", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.callout)
        } else if !importManager.songs.isEmpty {
            Text("\(importManager.readyCount) of \(importManager.songs.count) file\(importManager.songs.count == 1 ? "" : "s") ready")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }

    var importButton: some View {
        Button {
            guard let drive = selectedDrive else { return }
            Task { await importManager.importAll(to: drive.url) }
        } label: {
            if importManager.isImporting {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.75)
                    Text("Importing…")
                }
                .frame(minWidth: 110)
            } else {
                Text("Import to Drive")
                    .frame(minWidth: 110)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedDrive == nil || importManager.readyCount == 0 || importManager.isImporting)
    }

    // MARK: - Helpers

    @discardableResult
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let str = String(data: data, encoding: .utf8),
                      let url = URL(string: str) else { return }
                DispatchQueue.main.async { importManager.addFiles([url]) }
            }
        }
        return true
    }

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Select Rock Band 3 CON files"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK else { return }
            importManager.addFiles(panel.urls)
        }
    }
}

// MARK: - Song Row

struct SongRow: View {
    let song: SongEntry
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
            info
            Spacer()
            if let header = song.header {
                typeTag(header.contentTypeName)
            }
            statusText
            if !song.status.isTerminal && song.status != .copying {
                removeButton
            }
        }
        .padding(.vertical, 3)
    }

    var statusIcon: some View {
        Image(systemName: song.status.iconName)
            .foregroundStyle(statusColor)
            .frame(width: 18)
    }

    var info: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(song.displayName)
                .lineLimit(1)
            Text(song.filename)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    func typeTag(_ label: String) -> some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    var statusText: some View {
        Text(song.status.label)
            .font(.caption)
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .frame(minWidth: 70, alignment: .trailing)
    }

    var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
    }

    var statusColor: Color {
        switch song.status {
        case .pending:  return .secondary
        case .ready:    return .green
        case .copying:  return .blue
        case .copied:   return .green
        case .skipped:  return .secondary
        case .failed:   return .red
        }
    }
}
