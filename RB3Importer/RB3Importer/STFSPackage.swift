import Foundation
import AppKit

enum STFSError: LocalizedError {
    case fileTooSmall
    case invalidMagic(String)
    case wrongTitleID(UInt32)
    case unknownContentType(UInt32)
    case writeError(String)

    var errorDescription: String? {
        switch self {
        case .fileTooSmall: return "File too small to be a valid STFS package"
        case .invalidMagic(let m): return "Not an STFS package (magic: '\(m)')"
        case .wrongTitleID(let id): return "Wrong Title ID \(String(format: "%08X", id)), expected RB3 (45410914)"
        case .unknownContentType(let ct): return "Unknown content type \(String(format: "%08X", ct))"
        case .writeError(let msg): return "Failed to write metadata: \(msg)"
        }
    }
}

struct STFSHeader {
    let magic: String
    let contentType: UInt32
    let titleID: UInt32
    let displayName: String
    let displayDescription: String
    let thumbnailData: Data?
    let fileSize: UInt64

    static let rb3TitleID: UInt32 = 0x45410914

    static let displayNameOffset = 0x411
    static let displayNameMaxBytes = 0x80
    static let descriptionOffset = 0xD11
    static let descriptionMaxBytes = 0x80
    static let thumbnailSizeOffset = 0x1712
    static let thumbnailDataOffset = 0x171A
    static let thumbnailMaxBytes = 0x4000

    var contentFolder: String? {
        switch contentType {
        case 0x00000001: return "00000001"
        case 0x00000002: return "00000002"
        case 0x000B0000: return "000B0000"
        default: return nil
        }
    }

    var contentTypeName: String {
        switch contentType {
        case 0x00000001: return "CON (SavedGame)"
        case 0x00000002: return "LIVE (DLC)"
        case 0x000B0000: return "Title Update"
        default: return String(format: "%08X", contentType)
        }
    }

    var isRB3: Bool { titleID == Self.rb3TitleID }

    var artist: String {
        let parsed = Self.parseArtistAndAlbum(from: displayDescription, displayName: displayName)
        return parsed.artist ?? "Unknown Artist"
    }

    var album: String {
        let parsed = Self.parseArtistAndAlbum(from: displayDescription, displayName: displayName)
        return parsed.album ?? ""
    }

    var thumbnailImage: NSImage? {
        guard let data = thumbnailData, !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    static func parseArtistAndAlbum(from description: String, displayName: String = "") -> (artist: String?, album: String?) {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try parsing description in format: "Song" -- Artist. Credits...
        if let dashRange = trimmed.range(of: "--") ?? trimmed.range(of: " - ") {
            var afterDash = String(trimmed[dashRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip trailing credit/promo text
            for cutoff in ["Song credits", "Credits at", "http://", "https://", "Brought to you", "For more", "Visit us", ". "] {
                if let cutRange = afterDash.range(of: cutoff, options: .caseInsensitive) {
                    afterDash = String(afterDash[afterDash.startIndex..<cutRange.lowerBound])
                }
            }
            afterDash = afterDash.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ".")))

            if !afterDash.isEmpty && !afterDash.lowercased().hasPrefix("brought to you") {
                return (afterDash, nil)
            }
        }

        // Try parsing description as "Artist - Album"
        if !trimmed.isEmpty && !trimmed.lowercased().hasPrefix("brought to you") {
            if let range = trimmed.range(of: " - ") {
                let part1 = String(trimmed[trimmed.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let part2 = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !part1.isEmpty { return (part1, part2.isEmpty ? nil : part2) }
            }
        }

        // Try parsing display name as "Artist - Song" or "Artist – Song"
        let name = displayName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "\"")))
        for sep in [" – ", " - "] {
            if let range = name.range(of: sep) {
                let artist = String(name[name.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !artist.isEmpty { return (artist, nil) }
            }
        }

        return (nil, nil)
    }
}

func parseSTFSHeader(from url: URL) throws -> STFSHeader {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard data.count >= 0x500 else { throw STFSError.fileTooSmall }

    let magicRaw = String(bytes: data[0..<4], encoding: .ascii) ?? ""
    let magic = magicRaw.trimmingCharacters(in: .whitespaces)
    guard ["CON", "LIVE", "PIRS"].contains(magic) else {
        throw STFSError.invalidMagic(magic)
    }

    let contentType = data.readUInt32BE(at: 0x344)
    let titleID = data.readUInt32BE(at: 0x360)
    let displayName = data.readUTF16BEString(at: STFSHeader.displayNameOffset, maxBytes: STFSHeader.displayNameMaxBytes) ?? url.lastPathComponent
    let displayDescription: String
    if data.count > STFSHeader.descriptionOffset + STFSHeader.descriptionMaxBytes {
        displayDescription = data.readUTF16BEString(at: STFSHeader.descriptionOffset, maxBytes: STFSHeader.descriptionMaxBytes) ?? ""
    } else {
        displayDescription = ""
    }

    var thumbnailData: Data? = nil
    if data.count >= STFSHeader.thumbnailDataOffset + 8 {
        let thumbnailSize = Int(data.readUInt32BE(at: STFSHeader.thumbnailSizeOffset))
        if thumbnailSize > 0 && thumbnailSize <= STFSHeader.thumbnailMaxBytes {
            let thumbEnd = STFSHeader.thumbnailDataOffset + thumbnailSize
            if thumbEnd <= data.count {
                thumbnailData = data[STFSHeader.thumbnailDataOffset..<thumbEnd]
            }
        }
    }

    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0

    return STFSHeader(
        magic: magic,
        contentType: contentType,
        titleID: titleID,
        displayName: displayName,
        displayDescription: displayDescription,
        thumbnailData: thumbnailData,
        fileSize: fileSize
    )
}

func writeSTFSMetadata(to url: URL, displayName: String, description: String, thumbnail: Data?) throws {
    var data = try Data(contentsOf: url)
    guard data.count >= 0x571A else { throw STFSError.fileTooSmall }

    data.writeUTF16BEString(displayName, at: STFSHeader.displayNameOffset, maxBytes: STFSHeader.displayNameMaxBytes)
    data.writeUTF16BEString(description, at: STFSHeader.descriptionOffset, maxBytes: STFSHeader.descriptionMaxBytes)

    if let thumb = thumbnail {
        let clampedSize = min(thumb.count, STFSHeader.thumbnailMaxBytes)
        data.writeUInt32BE(UInt32(clampedSize), at: STFSHeader.thumbnailSizeOffset)
        let thumbRange = STFSHeader.thumbnailDataOffset..<(STFSHeader.thumbnailDataOffset + clampedSize)
        data.replaceSubrange(thumbRange, with: thumb[0..<clampedSize])
        if clampedSize < STFSHeader.thumbnailMaxBytes {
            let zeroFill = Data(count: STFSHeader.thumbnailMaxBytes - clampedSize)
            let fillRange = (STFSHeader.thumbnailDataOffset + clampedSize)..<(STFSHeader.thumbnailDataOffset + STFSHeader.thumbnailMaxBytes)
            data.replaceSubrange(fillRange, with: zeroFill)
        }
    }

    try data.write(to: url, options: .atomic)
}

extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) << 24
             | UInt32(self[offset + 1]) << 16
             | UInt32(self[offset + 2]) << 8
             | UInt32(self[offset + 3])
    }

    func readUTF16BEString(at offset: Int, maxBytes: Int) -> String? {
        let end = Swift.min(offset + maxBytes, count)
        guard offset + 1 < end else { return nil }
        var raw: [UInt8] = []
        var i = offset
        while i + 1 < end {
            if self[i] == 0 && self[i + 1] == 0 { break }
            raw.append(self[i])
            raw.append(self[i + 1])
            i += 2
        }
        guard !raw.isEmpty else { return nil }
        return String(bytes: raw, encoding: .utf16BigEndian)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func writeUInt32BE(_ value: UInt32, at offset: Int) {
        guard offset + 4 <= count else { return }
        self[offset]     = UInt8((value >> 24) & 0xFF)
        self[offset + 1] = UInt8((value >> 16) & 0xFF)
        self[offset + 2] = UInt8((value >> 8) & 0xFF)
        self[offset + 3] = UInt8(value & 0xFF)
    }

    mutating func writeUTF16BEString(_ string: String, at offset: Int, maxBytes: Int) {
        guard offset + maxBytes <= count else { return }
        var encoded: [UInt8] = []
        for scalar in string.unicodeScalars {
            if encoded.count + 2 > maxBytes - 2 { break }
            let val = UInt16(scalar.value)
            encoded.append(UInt8(val >> 8))
            encoded.append(UInt8(val & 0xFF))
        }
        while encoded.count < maxBytes {
            encoded.append(0)
        }
        for (i, byte) in encoded.enumerated() {
            self[offset + i] = byte
        }
    }
}
