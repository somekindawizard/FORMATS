import Foundation

/// A minimal store-only (uncompressed) ZIP writer — enough to assemble an EPUB
/// container, which Foundation can't otherwise produce. Entries are stored, not
/// deflated, which EPUB permits (and the first entry, mimetype, requires).
struct ZipWriter {
    private struct Entry { let name: String; let size: Int; let crc: UInt32; let offset: Int }
    private var out = [UInt8]()
    private var entries = [Entry]()

    mutating func add(_ name: String, bytes: [UInt8]) {
        let crc = CRC32.checksum(bytes)
        let offset = out.count
        let nameBytes = Array(name.utf8)
        out += le32(0x04034b50)                 // local file header signature
        out += le16(20)                         // version needed
        out += le16(0)                          // flags
        out += le16(0)                          // method: store
        out += le16(0) + le16(0)                // mod time / date
        out += le32(crc)
        out += le32(UInt32(bytes.count))        // compressed size
        out += le32(UInt32(bytes.count))        // uncompressed size
        out += le16(UInt16(nameBytes.count))
        out += le16(0)                          // extra length
        out += nameBytes
        out += bytes
        entries.append(Entry(name: name, size: bytes.count, crc: crc, offset: offset))
    }

    mutating func finalize() -> Data {
        let cdStart = out.count
        for e in entries {
            let nameBytes = Array(e.name.utf8)
            out += le32(0x02014b50)             // central directory header
            out += le16(20) + le16(20)          // version made by / needed
            out += le16(0) + le16(0)            // flags / method
            out += le16(0) + le16(0)            // time / date
            out += le32(e.crc)
            out += le32(UInt32(e.size)) + le32(UInt32(e.size))
            out += le16(UInt16(nameBytes.count))
            out += le16(0) + le16(0)            // extra / comment length
            out += le16(0) + le16(0)            // disk number / internal attrs
            out += le32(0)                      // external attrs
            out += le32(UInt32(e.offset))
            out += nameBytes
        }
        let cdSize = out.count - cdStart
        out += le32(0x06054b50)                 // end of central directory
        out += le16(0) + le16(0)                // disk numbers
        out += le16(UInt16(entries.count)) + le16(UInt16(entries.count))
        out += le32(UInt32(cdSize))
        out += le32(UInt32(cdStart))
        out += le16(0)                          // comment length
        return Data(out)
    }

    private func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }
    static func checksum(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in bytes { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}
