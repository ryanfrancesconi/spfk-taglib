// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// A frame that cannot be read is skipped when another frame, padding or the end of the tag follows
/// where its size ends; otherwise the tag ends there.
@Suite
struct ID3v2InvalidFrameTests {
    private static func le32(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) }
    }

    private static func synchsafe(_ value: Int) -> Data {
        Data((0 ..< 4).reversed().map { UInt8((value >> (7 * $0)) & 0x7F) })
    }

    /// A v2.4 frame: ID, synchsafe size, no flags, a Latin-1 text body.
    private static func frame(_ id: [UInt8], _ text: String) -> Data {
        let body = Data([0]) + Data(text.utf8)
        return Data(id) + synchsafe(body.count) + Data([0, 0]) + body
    }

    private static func frame(_ id: String, _ text: String) -> Data {
        frame(Array(id.utf8), text)
    }

    /// A WAV, 8-bit mono at 8 kHz, whose `ID3 ` chunk is a v2.4 tag of `frames`.
    private func write(frames: Data) throws -> String {
        let tag = Data("ID3".utf8) + Data([4, 0, 0]) + Self.synchsafe(frames.count) + frames
        let format = Data([1, 0, 1, 0]) + Self.le32(8000) + Self.le32(8000) + Data([1, 0, 8, 0])
        let audio = Data(repeating: 0x80, count: 800)
        var body = Data("WAVE".utf8)
        body.append(Data("fmt ".utf8) + Self.le32(format.count) + format)
        body.append(Data("data".utf8) + Self.le32(audio.count) + audio)
        body.append(Data("ID3 ".utf8) + Self.le32(tag.count) + tag)
        if tag.count % 2 == 1 { body.append(0) }

        let path = NSTemporaryDirectory() + "taglib-id3-\(UUID().uuidString).wav"
        try (Data("RIFF".utf8) + Self.le32(body.count) + body).write(to: URL(fileURLWithPath: path))
        return path
    }

    private func frames(at path: String) -> [String] {
        var list = wavID3v2Frames(path)
        return withUnsafeBytes(of: &list.frames) { raw in
            let states = raw.bindMemory(to: ID3v2FrameState.self)
            return (0 ..< min(Int(list.frameCount), 8)).map { index in
                var state = states[index]
                let id = withUnsafeBytes(of: &state.frameID) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
                let text = withUnsafeBytes(of: &state.text) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
                return "\(id)=\(text)"
            }
        }
    }

    @Test func framesAfterAnInvalidIDAreReadAndKept() throws {
        let path = try write(frames: Self.frame("TIT2", "Title") + Self.frame([0xFF, 0x4C, 0x45, 0x4E], "1")
            + Self.frame("TPE1", "Artist") + Self.frame("TALB", "Album"))

        #expect(frames(at: path) == ["TIT2=Title", "TPE1=Artist", "TALB=Album"])

        // A save renders the tag from what was read.
        #expect(wavSetDISPTexts(path, nil, 0))
        #expect(frames(at: path) == ["TIT2=Title", "TPE1=Artist", "TALB=Album"])
    }

    @Test func aV22IDPaddedWithASpaceInAV24TagIsSkipped() throws {
        let path = try write(frames: Self.frame("TIT2", "Title") + Self.frame("CM1 ", "x") + Self.frame("TALB", "Album"))

        #expect(frames(at: path) == ["TIT2=Title", "TALB=Album"])
    }

    @Test func aFrameFollowedByGarbageStillEndsTheTag() throws {
        let path = try write(frames: Self.frame("TIT2", "Title") + Self.frame([0xFF, 0x4C, 0x45, 0x4E], "1")
            + Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A]) + Self.frame("TALB", "Album"))

        #expect(frames(at: path) == ["TIT2=Title"])
    }
}
