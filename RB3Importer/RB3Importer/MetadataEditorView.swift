import SwiftUI
import AppKit

struct MetadataEditorView: View {
    let song: LibrarySong
    let onSave: () -> Void

    @State private var songName: String
    @State private var artist: String
    @State private var album: String
    @State private var artworkImage: NSImage?
    @State private var newThumbnailData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(song: LibrarySong, onSave: @escaping () -> Void) {
        self.song = song
        self.onSave = onSave
        _songName = State(initialValue: song.header.displayName)
        _artist = State(initialValue: song.header.artist)
        _album = State(initialValue: song.header.album)
        _artworkImage = State(initialValue: song.header.thumbnailImage)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Song Information") {
                    TextField("Song Name", text: $songName)
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                }

                Section("Artwork") {
                    HStack(spacing: 16) {
                        if let image = artworkImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 128, height: 128)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 128, height: 128)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.tertiary)
                                }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Button("Choose Image…") { pickArtwork() }
                            if artworkImage != nil {
                                Button("Remove Artwork") {
                                    artworkImage = nil
                                    newThumbnailData = Data()
                                }
                                .foregroundStyle(.red)
                            }
                            Text("PNG or JPEG, max 64x64 recommended")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let err = errorMessage {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(song.fileSizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 400)
    }

    private func pickArtwork() {
        let panel = NSOpenPanel()
        panel.title = "Select Artwork Image"
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let image = NSImage(contentsOf: url),
                  let data = try? Data(contentsOf: url) else { return }
            artworkImage = image
            newThumbnailData = data
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        let description: String
        if !artist.isEmpty && !album.isEmpty {
            description = "\(artist) - \(album)"
        } else if !artist.isEmpty {
            description = artist
        } else {
            description = album
        }

        do {
            try writeSTFSMetadata(
                to: song.url,
                displayName: songName,
                description: description,
                thumbnail: newThumbnailData
            )
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
