import Foundation
import AppKit

enum RockBandGame: String, CaseIterable, Hashable {
    case rb1 = "RB1"
    case rb2 = "RB2"
    case rb3 = "RB3"

    var titleID: UInt32 {
        switch self {
        case .rb1: return 0x45410829
        case .rb2: return 0x45410869
        case .rb3: return 0x45410914
        }
    }

    var titleIDHex: String {
        String(format: "%08X", titleID)
    }

    var basePath: String {
        "Content/0000000000000000/\(titleIDHex)"
    }

    /// Where songs should be synced on the drive — RB1 songs go into the RB2 folder
    /// because RB3/RB3DX scans RB2's content folder but not RB1's.
    var syncBasePath: String {
        switch self {
        case .rb1: return RockBandGame.rb2.basePath
        case .rb2: return basePath
        case .rb3: return basePath
        }
    }

    var label: String { rawValue }

    static func from(titleID: UInt32) -> RockBandGame? {
        allCases.first { $0.titleID == titleID }
    }
}

enum STFSError: LocalizedError {
    case fileTooSmall
    case invalidMagic(String)
    case wrongTitleID(UInt32)
    case unknownContentType(UInt32)
    var errorDescription: String? {
        switch self {
        case .fileTooSmall: return "File too small to be a valid STFS package"
        case .invalidMagic(let m): return "Not an STFS package (magic: '\(m)')"
        case .wrongTitleID(let id): return "Wrong Title ID \(String(format: "%08X", id)), not a Rock Band 2 or 3 package"
        case .unknownContentType(let ct): return "Unknown content type \(String(format: "%08X", ct))"
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
    var songInfo: RB3SongInfo?

    static let rb3TitleID: UInt32 = RockBandGame.rb3.titleID
    static let rb2TitleID: UInt32 = RockBandGame.rb2.titleID

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

    var game: RockBandGame? { RockBandGame.from(titleID: titleID) }
    var isRockBand: Bool { game != nil }
    var isRB3: Bool { titleID == Self.rb3TitleID }
    var isRB2: Bool { titleID == Self.rb2TitleID }

    var artist: String {
        if let si = songInfo, !si.artist.isEmpty { return si.artist }
        let parsed = Self.parseArtistAndAlbum(from: displayDescription, displayName: displayName)
        return parsed.artist ?? "Unknown Artist"
    }

    var album: String {
        if let si = songInfo, !si.albumName.isEmpty { return si.albumName }
        return ""
    }

    var trackName: String {
        if let si = songInfo, !si.trackName.isEmpty { return si.trackName }
        // Fall back to display name, stripping "Artist - " prefix
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        for sep in [" – ", " - "] {
            if let range = name.range(of: sep) {
                let after = String(name[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !after.isEmpty { return after }
            }
        }
        return displayName
    }

    var thumbnailImage: NSImage? {
        guard let data = thumbnailData, !data.isEmpty else { return nil }
        return NSImage(data: data)
    }


    static func parseArtistAndAlbum(from description: String, displayName: String = "") -> (artist: String?, album: String?) {
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

func parseSTFSHeader(from url: URL, skipDTA: Bool = false) throws -> STFSHeader {
    let readLength = skipDTA ? min(0x6000, Int.max) : Int.max
    let fileHandle = try FileHandle(forReadingFrom: url)
    defer { try? fileHandle.close() }
    let data: Data
    if skipDTA {
        data = fileHandle.readData(ofLength: readLength)
    } else {
        data = try Data(contentsOf: url, options: .mappedIfSafe)
    }
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
    if !skipDTA, data.count >= STFSHeader.thumbnailDataOffset + 8 {
        let thumbnailSize = Int(data.readUInt32BE(at: STFSHeader.thumbnailSizeOffset))
        if thumbnailSize > 0 && thumbnailSize <= STFSHeader.thumbnailMaxBytes {
            let thumbEnd = STFSHeader.thumbnailDataOffset + thumbnailSize
            if thumbEnd <= data.count {
                thumbnailData = data[STFSHeader.thumbnailDataOffset..<thumbEnd]
            }
        }
    }

    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0

    var songInfo: RB3SongInfo? = nil
    if !skipDTA, let dtaData = extractFileFromSTFS(data: data, matching: { $0.lowercased().hasSuffix(".dta") }) {
        songInfo = parseRB3SongInfo(from: dtaData)
    }

    return STFSHeader(
        magic: magic,
        contentType: contentType,
        titleID: titleID,
        displayName: displayName,
        displayDescription: displayDescription,
        thumbnailData: thumbnailData,
        fileSize: fileSize,
        songInfo: songInfo
    )
}

// MARK: - STFS File Extraction

struct STFSFileEntry {
    let filename: String
    let isDirectory: Bool
    let isConsecutive: Bool
    let numBlocks: Int
    let startingBlock: Int
    let fileSize: Int
}

func extractFileFromSTFS(data: Data, matching predicate: (String) -> Bool) -> Data? {
    let magic = String(bytes: data[0..<4], encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
    let headerSize = magic == "CON" ? 0xB000 : 0xA000

    guard data.count > headerSize else { return nil }

    let ftBlockCount = Int(data.readUInt16LE(at: 0x37C))
    let ftStartBlock = data.readInt24LE(at: 0x37E)

    guard ftBlockCount > 0 else { return nil }

    func blockToOffset(_ block: Int) -> Int {
        var hashBlocksBefore = (block / 170) + 1
        if block >= 170 {
            hashBlocksBefore += (block / (170 * 170)) + 1
        }
        let backingBlock = block + hashBlocksBefore
        return headerSize + (backingBlock * 0x1000)
    }

    var entries: [STFSFileEntry] = []
    for tableIdx in 0..<ftBlockCount {
        let tableOffset = blockToOffset(ftStartBlock + tableIdx)
        guard tableOffset + 0x1000 <= data.count else { break }

        for i in 0..<64 {
            let entryOffset = tableOffset + (i * 0x40)
            guard entryOffset + 0x40 <= data.count else { break }

            let flagsByte = data[entryOffset + 0x28]
            let nameLen = Int(flagsByte & 0x3F)
            guard nameLen > 0 else { continue }

            let nameData = data[entryOffset..<(entryOffset + min(nameLen, 0x28))]
            let filename = String(bytes: nameData, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters) ?? ""
            guard !filename.isEmpty else { continue }

            let isDirectory = (flagsByte & 0x40) != 0
            let isConsecutive = (flagsByte & 0x80) != 0
            let numBlocks = data.readInt24LE(at: entryOffset + 0x29)
            let startingBlock = data.readInt24LE(at: entryOffset + 0x2F)
            let fileSize = Int(data.readUInt32BE(at: entryOffset + 0x34))

            entries.append(STFSFileEntry(
                filename: filename,
                isDirectory: isDirectory,
                isConsecutive: isConsecutive,
                numBlocks: numBlocks,
                startingBlock: startingBlock,
                fileSize: fileSize
            ))
        }
    }

    guard let entry = entries.first(where: { predicate($0.filename) && $0.fileSize > 0 }) else {
        return nil
    }

    var fileData = Data()
    for i in 0..<entry.numBlocks {
        let blockNum = entry.startingBlock + i
        let offset = blockToOffset(blockNum)
        guard offset + 0x1000 <= data.count else { break }
        fileData.append(data[offset..<(offset + 0x1000)])
    }

    if fileData.count > entry.fileSize {
        fileData = fileData.prefix(entry.fileSize)
    }
    return fileData.isEmpty ? nil : fileData
}

// MARK: - DTA Parsing

struct RB3SongInfo {
    var trackName: String = ""
    var artist: String = ""
    var albumName: String = ""
    var yearReleased: String = ""
    var genre: String = ""
    var songLength: String = ""
    var vocalParts: String = ""
}

func parseRB3SongInfo(from dtaData: Data) -> RB3SongInfo? {
    guard let raw = String(data: dtaData, encoding: .utf8)
            ?? String(data: dtaData, encoding: .isoLatin1) else { return nil }

    var info = RB3SongInfo()

    func extractQuoted(_ key: String) -> String? {
        let patterns = ["'\(key)'", "(\(key)"]
        for pattern in patterns {
            guard let range = raw.range(of: pattern, options: .caseInsensitive) else { continue }
            let after = raw[range.upperBound...]
            guard let openQuote = after.firstIndex(of: "\"") else { continue }
            let valueStart = after.index(after: openQuote)
            guard let closeQuote = after[valueStart...].firstIndex(of: "\"") else { continue }
            let value = String(after[valueStart..<closeQuote])
            if !value.isEmpty && !value.contains("/") || key == "album_name" {
                return value
            }
        }
        return nil
    }

    func extractSymbol(_ key: String) -> String? {
        let patterns = ["'\(key)'", "(\(key)"]
        for pattern in patterns {
            guard let range = raw.range(of: pattern, options: .caseInsensitive) else { continue }
            let after = raw[range.upperBound...].drop(while: { $0 == " " || $0 == "\r" || $0 == "\n" || $0 == "'" })
            let token = after.prefix(while: { $0 != ")" && $0 != " " && !$0.isNewline })
            let value = String(token).trimmingCharacters(in: CharacterSet.whitespaces.union(.init(charactersIn: "'")))
            if !value.isEmpty { return value }
        }
        return nil
    }

    if let n = extractQuoted("song_name") {
        info.trackName = n
    } else {
        info.trackName = extractQuoted("name") ?? ""
    }

    info.artist = extractQuoted("artist") ?? ""
    info.albumName = extractQuoted("album_name") ?? ""
    info.yearReleased = extractSymbol("year_released") ?? ""
    info.genre = extractSymbol("genre")?.replacingOccurrences(of: "_", with: " ") ?? ""

    if let ms = extractSymbol("song_length"), let msInt = Int(ms) {
        let seconds = msInt / 1000
        info.songLength = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    if let vp = extractSymbol("vocal_parts") {
        info.vocalParts = vp
    }

    return (info.artist.isEmpty && info.trackName.isEmpty) ? nil : info
}

func extractRB3SongInfo(from url: URL) -> RB3SongInfo? {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
          let dtaData = extractFileFromSTFS(data: data, matching: { $0.lowercased().hasSuffix(".dta") }),
          let info = parseRB3SongInfo(from: dtaData) else { return nil }
    return info
}

// MARK: - Data Helpers

extension Data {
    func readUInt16BE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }

    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func readInt24BE(at offset: Int) -> Int {
        guard offset + 3 <= count else { return 0 }
        return Int(self[offset]) << 16 | Int(self[offset + 1]) << 8 | Int(self[offset + 2])
    }

    func readInt24LE(at offset: Int) -> Int {
        guard offset + 3 <= count else { return 0 }
        return Int(self[offset]) | Int(self[offset + 1]) << 8 | Int(self[offset + 2]) << 16
    }

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
