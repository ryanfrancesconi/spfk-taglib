// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// RF64 and BW64 are the long forms of WAVE, used past 4 GB: the 32-bit size fields hold a
/// `0xFFFFFFFF` sentinel and a leading `ds64` chunk carries the real sizes. Writing a real
/// number into the sentinel makes readers stop consulting `ds64`, which past 4 GB is the only
/// place the size fits — so the file's audio is lost even though every byte is still on disk.
///
/// The bundled fixture is 50 ms, which is enough: the detection failure and the sentinel
/// overwrite are the same code at any size. Verified against a 4.8 GB RF64 as well —
/// Core Audio reports 25000.000000 sec and 4,800,000,000 audio bytes after a tag write.
@Suite
final class RF64Tests {
    static let fixtureURL: URL = {
        Bundle.module.url(forResource: "rf64", withExtension: "wav", subdirectory: "Resources")!
    }()

    /// Copies the fixture, optionally rewriting the four magic bytes at offset 0.
    private func makeCopy(magic: String = "RF64") throws -> String {
        let path = NSTemporaryDirectory() + "taglib-rf64-\(UUID().uuidString).wav"
        #expect(copyTestFile(Self.fixtureURL.path, path))

        if magic != "RF64" {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: Data(magic.utf8))
        }

        return path
    }

    private func readProperty(_ key: String, from path: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        guard wavReadProperty(path, key, &buffer, 256) else { return nil }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Detection

    @Test(arguments: ["RF64", "BW64"])
    func longFormMagicIsSupported(magic: String) throws {
        let path = try makeCopy(magic: magic)
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(wavIsSupported(path))
    }

    @Test func garbageMagicIsNotSupported() throws {
        let path = try makeCopy(magic: "XX64")
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(!wavIsSupported(path))
    }

    // MARK: - Read

    /// The `data` chunk's declared size is a sentinel, so a reader that does not consult `ds64`
    /// reports a duration derived from whatever it clamped to instead.
    ///
    /// A trailing chunk is appended first, because with `data` last the clamp coincidentally
    /// lands on the right answer and the test proves nothing.
    @Test func audioPropertiesComeFromDS64() throws {
        let path = try makeCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        try handle.seekToEnd()
        // 1000 bytes past the audio: enough to move a clamped duration from 50 ms to 55.
        try handle.write(contentsOf: Data("junk".utf8) + Data([0xE8, 0x03, 0x00, 0x00])
            + Data(repeating: 0, count: 1000))
        try handle.close()

        let props = wavAudioProperties(path)
        #expect(props.lengthMs == 50)
        #expect(props.sampleRate == 48000)
        #expect(props.channels == 2)
    }

    // MARK: - Write

    @Test(arguments: ["RF64", "BW64"])
    func tagWriteRoundTrips(magic: String) throws {
        let path = try makeCopy(magic: magic)
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(wavWriteProperties(path, "probe title", "probe artist"))

        #expect(readProperty("TITLE", from: path) == "probe title")
        #expect(readProperty("ARTIST", from: path) == "probe artist")
    }

    /// The write must leave the sentinel and the audio's extent alone. Checked against the raw
    /// bytes rather than through TagLib, so a reader that is wrong in both directions cannot
    /// make this pass.
    @Test func tagWriteLeavesTheAudioIntact() throws {
        let path = try makeCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let before = riffHeaderInfo(path)
        #expect(before.hasDS64)
        #expect(before.dataSize == 9600)

        #expect(wavWriteProperties(path, "probe title", "probe artist"))

        let after = riffHeaderInfo(path)
        #expect(after.sizeField == 0xFFFF_FFFF)
        #expect(after.dataChunkDeclaredSize == 0xFFFF_FFFF)
        #expect(after.dataSize == before.dataSize)
        #expect(after.dataChunkOffset == before.dataChunkOffset)
        #expect(after.fileSize > before.fileSize)

        // ds64 is where the true size lives, so it has to track the file's growth.
        #expect(after.riffSize == after.fileSize - 8)
    }

    /// A file an older TagLib damaged carries a real 32-bit total where the sentinel belongs —
    /// past 4 GB a truncated one, which is what makes readers report milliseconds for hours of
    /// audio. The value is malformed in a long-form file whatever its size, so a save writes the
    /// sentinel back and the file reads correctly again everywhere.
    @Test func saveRepairsAClobberedSentinel() throws {
        let path = try makeCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        try handle.seek(toOffset: 4)
        try handle.write(contentsOf: Data([0x6E, 0x14, 0x00, 0x00]))  // 5230, as an old save leaves it
        try handle.close()

        #expect(riffHeaderInfo(path).sizeField == 5230)

        #expect(wavWriteProperties(path, "probe title", "probe artist"))

        let after = riffHeaderInfo(path)
        #expect(after.sizeField == 0xFFFF_FFFF)
        #expect(after.riffSize == after.fileSize - 8)
        #expect(after.dataSize == 9600)
    }

    /// The long-form branch must not reach an ordinary WAV, whose 32-bit size field is real and
    /// has to keep tracking the file.
    @Test func plainRIFFStillGetsARealSize() throws {
        let path = try makeCopy(magic: "RIFF")
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Give the data chunk its true size, so the file is a valid plain RIFF.
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
        let before = riffHeaderInfo(path)
        try handle.seek(toOffset: UInt64(before.dataChunkOffset - 4))
        try handle.write(contentsOf: Data([0x80, 0x25, 0x00, 0x00]))  // 9600, little-endian
        try handle.seek(toOffset: 4)
        try handle.write(contentsOf: Data([0xC8, 0x25, 0x00, 0x00]))  // 9672
        try handle.close()

        #expect(wavWriteProperties(path, "probe title", "probe artist"))

        let after = riffHeaderInfo(path)
        #expect(after.sizeField == UInt32(after.fileSize - 8))
        #expect(readProperty("TITLE", from: path) == "probe title")
    }

    /// A duration that moves across a tag write means the reader is measuring the audio with
    /// the tag chunks included — the shape the sentinel produces when `ds64` is ignored.
    @Test func durationSurvivesATagWrite() throws {
        let path = try makeCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let before = wavAudioProperties(path)
        #expect(wavWriteProperties(path, "probe title", "probe artist"))
        let after = wavAudioProperties(path)

        #expect(after.lengthMs == before.lengthMs)
        #expect(after.lengthMs == 50)
    }
}
