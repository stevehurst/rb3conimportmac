import SwiftUI

struct DuplicateResolverView: View {
    let duplicates: [DuplicateGroup]
    let onResolve: (_ keep: UUID, _ remove: UUID) -> Void
    let onDismiss: () -> Void

    @State private var currentIndex = 0

    private var current: DuplicateGroup? {
        guard currentIndex < duplicates.count else { return nil }
        return duplicates[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let group = current {
                duplicateComparison(group)
            }

            Divider()
            footer
        }
        .frame(minWidth: 500, minHeight: 300)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Label("Duplicate Songs Found", systemImage: "doc.on.doc.fill")
                .font(.headline)
            Text("\(duplicates.count) duplicate\(duplicates.count == 1 ? "" : " groups") detected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func duplicateComparison(_ group: DuplicateGroup) -> some View {
        VStack(spacing: 12) {
            Text(group.songName)
                .font(.title3.bold())
            Text(group.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(group.files) { file in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.url.lastPathComponent)
                            .lineLimit(1)
                        Text(file.fileSizeFormatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(file.url.deletingLastPathComponent().path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if file.id == group.files.first?.id {
                        Text("Largest")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.green)
                    }
                    Button("Keep") {
                        let others = group.files.filter { $0.id != file.id }
                        for other in others {
                            onResolve(file.id, other.id)
                        }
                        advance()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if duplicates.count > 1 {
                Text("\(currentIndex + 1) of \(duplicates.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Skip All") { onDismiss() }
        }
        .padding()
    }

    private func advance() {
        if currentIndex + 1 < duplicates.count {
            currentIndex += 1
        } else {
            onDismiss()
        }
    }
}
