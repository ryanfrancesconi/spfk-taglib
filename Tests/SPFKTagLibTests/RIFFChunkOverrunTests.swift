// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// A chunk running past the end of a WAV: an APEv2 tag appended after the chunks, whose `APETAGEX`
/// reads as a chunk ID with a size far past the end, or an audio chunk declaring more than the file
/// holds. Tags a save writes must not be read as part of either.
@Suite
struct RIFFChunkOverrunTests {
    private static func le32(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) }
    }

    /// `fmt ` and then `data`, 8-bit mono at 8 kHz, declaring `extra` more audio bytes than it holds.
    private static func wave(extra: Int = 0) -> Data {
        let format = Data([1, 0, 1, 0]) + le32(8000) + le32(8000) + Data([1, 0, 8, 0])
        let audio = Data(repeating: 0x80, count: 800)
        let body = Data("WAVE".utf8) + Data("fmt ".utf8) + le32(format.count) + format
            + Data("data".utf8) + le32(audio.count + extra) + audio
        return Data("RIFF".utf8) + le32(body.count) + body
    }

    /// An APEv2 tag with a header, one `Title` item and a footer.
    private static let apeTag: Data = {
        let value = Data("ape title".utf8)
        let item = le32(value.count) + le32(0) + Data("Title".utf8) + Data([0]) + value
        func header(_ flags: Int) -> Data {
            Data("APETAGEX".utf8) + le32(2000) + le32(item.count + 32) + le32(1) + le32(flags) + Data(count: 8)
        }
        return header(0xA000_0000) + item + header(0x8000_0000)
    }()

    private func write(_ data: Data) throws -> String {
        let path = NSTemporaryDirectory() + "taglib-overrun-\(UUID().uuidString).wav"
        try data.write(to: URL(fileURLWithPath: path))
        return path
    }

    private func title(at path: String) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard wavReadProperty(path, "TITLE", &buffer, 256) else { return "" }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    @Test func aTrailingAPETagIsNotReadAsAChunk() throws {
        let path = try write(Self.wave() + Self.apeTag)

        #expect(wavWriteProperties(path, "Title", "Artist"))

        #expect(title(at: path) == "Title")
        #expect(try Data(contentsOf: URL(fileURLWithPath: path)).suffix(Self.apeTag.count) == Self.apeTag)
    }

    @Test func tagsSavedAfterAnOversizedDataChunkAreReadBack() throws {
        let path = try write(Self.wave(extra: 100))

        #expect(wavWriteProperties(path, "Title", "Artist"))

        #expect(title(at: path) == "Title")
    }
}
