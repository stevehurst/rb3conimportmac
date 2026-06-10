import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var library: LibraryManager
    @State private var editingSong: LibrarySong?
    @State private var showDuplicates = false
    @State private var searchText = ""
    @State private var expandedArtists: Set<String> = []

    private var filteredGroups: [ArtistGroup] {
        if searchText.isEmpty { return library.artistGroups }
        return library.artistGroups.compactMap { group in
            let filtered = group.songs.filter {
                $0.songName.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText) ||
                $0.album.localizedCaseInsensitiveContains(searchText)
            }
            guard !filtered.isEmpty else { return nil }
            return ArtistGroup(artist: group.artist, songs: filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if library.libraryPath == nil {
                emptyState
            } else if library.isScanning {
                scanningState
            } else if library.allSongs.isEmpty {
                emptyLibrary
            } else {
                toolbar
                Divider()
                songList
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
        .sheet(item: $editingSong) { song in
            MetadataEditorView(song: song) {
                library.refreshSong(at: song.url)
            }
        }
        .sheet(isPresented: $showDuplicates) {
            DuplicateResolverView(
                duplicates: library.duplicates,
                onResolve: { keep, remove in library.resolveDuplicate(keep: keep, remove: remove) },
                onDismiss: { showDuplicates = false }
            )
        }
        .onChange(of: library.duplicates) { _, dupes in
            if !dupes.isEmpty { showDuplicates = true }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("No Library Folder Selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Choose a folder containing your .rb3con files")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Button("Select Library Folder…") { library.selectLibraryFolder() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning library…")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("No Songs Found")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Drop .rb3con files here or add them to your library folder")
                .font(.callout)
                .foregroundStyle(.tertiary)
            HStack(spacing: 12) {
                Button("Change Folder…") { library.selectLibraryFolder() }
                Button("Rescan") { Task { await library.scan() } }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search songs…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 250)

            Spacer()

            Text("\(library.allSongs.count) songs")
                .font(.caption)
                .foregroundStyle(.secondary)

            if library.selectedSongIDs.count > 0 {
                Text("\(library.selectedSongIDs.count) selected")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            Menu {
                Button("Select All") { library.selectAll() }
                Button("Deselect All") { library.deselectAll() }
                Divider()
                Button("Expand All") {
                    expandedArtists = Set(library.artistGroups.map(\.artist))
                }
                Button("Collapse All") { expandedArtists.removeAll() }
                Divider()
                Button("Change Library Folder…") { library.selectLibraryFolder() }
                Button("Rescan Library") { Task { await library.scan() } }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var songList: some View {
        List {
            ForEach(filteredGroups) { group in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedArtists.contains(group.artist) },
                        set: { expanded in
                            if expanded { expandedArtists.insert(group.artist) }
                            else { expandedArtists.remove(group.artist) }
                        }
                    )
                ) {
                    ForEach(group.songs) { song in
                        LibrarySongRow(
                            song: song,
                            isSelected: library.selectedSongIDs.contains(song.id),
                            onToggle: { library.toggleSelection(song.id) },
                            onEdit: { editingSong = song }
                        )
                    }
                } label: {
                    HStack {
                        Text(group.artist)
                            .font(.headline)
                        Spacer()
                        Text("\(group.songs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            if expandedArtists.isEmpty {
                expandedArtists = Set(library.artistGroups.map(\.artist))
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard let data, let str = String(data: data, encoding: .utf8),
                      let url = URL(string: str) else { return }
                urls.append(url)
            }
        }
        group.notify(queue: .main) {
            library.addFiles(urls)
        }
    }
}

struct LibrarySongRow: View {
    let song: LibrarySong
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button { onToggle() } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            if let image = song.header.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(song.songName)
                    .lineLimit(1)
                if !song.album.isEmpty {
                    Text(song.album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(song.fileSizeFormatted)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button { onEdit() } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit metadata")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
