import Foundation

enum STFSError: LocalizedError {
    case fileTooSmall
    case invalidMagic(String)
    case wrongTitleID(UInt32)
    case unknownContentType(UInt32)

    var errorDescription: String? {
        switch self {
        case .fileTooSmall: return "File too small to be a valid STFS package"
        case .invalidMagic(let m): return "Not an STFS package (magic: '\(m)')"
        case .wrongTitleID(let id): return "Wrong Title ID \(String(format: "%08X", id)), expected RB3 (45410914)"
        case .unknownContentType(let ct): return "Unknown content type \(String(format: "%08X", ct))"
        }
    }
}

struct STFSHeader {
    let magic: String
    let contentType: UInt32
    let titleID: UInt32
    let displayName: String

    static let rb3TitleID: UInt32 = 0x45410914

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
    let displayName = data.readUTF16BEString(at: 0x411, maxBytes: 128) ?? url.lastPathComponent

    return STFSHeader(magic: magic, contentType: contentType, titleID: titleID, displayName: displayName)
}

private extension Data {
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
}
