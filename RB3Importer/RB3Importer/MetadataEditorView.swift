import SwiftUI
import AppKit

struct SongInfoView: View {
    let song: LibrarySong

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    infoRow("Game", "Rock Band \(song.game == .rb2 ? "2" : "3")")
                    if let info = song.header.songInfo {
                        infoRow("Track", info.trackName)
                        infoRow("Artist", info.artist)
                        if !info.albumName.isEmpty { infoRow("Album", info.albumName) }
                        if !info.yearReleased.isEmpty { infoRow("Year", info.yearReleased) }
                        if !info.genre.isEmpty { infoRow("Genre", info.genre.capitalized) }
                        if !info.songLength.isEmpty { infoRow("Length", info.songLength) }
                    } else {
                        Text("Could not read encoded song data")
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                } header: {
                    Text("Rock Band Song Data")
                } footer: {
                    Text("Encoded in the song package — displayed in Rock Band during gameplay.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section {
                    infoRow("Display Name", song.header.displayName)
                    if !song.header.displayDescription.isEmpty {
                        infoRow("Description", song.header.displayDescription)
                    }
                    if let image = song.header.thumbnailImage {
                        HStack {
                            Text("Thumbnail")
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .trailing)
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                                .cornerRadius(6)
                        }
                    }
                } header: {
                    Text("File Metadata")
                } footer: {
                    Text("Shown in the Xbox 360 dashboard file browser.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Section {
                    infoRow("Filename", song.url.lastPathComponent)
                    infoRow("File Size", song.fileSizeFormatted)
                    infoRow("Package Type", song.header.contentTypeName)
                } header: {
                    Text("File Info")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 400)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
        }
    }
}
