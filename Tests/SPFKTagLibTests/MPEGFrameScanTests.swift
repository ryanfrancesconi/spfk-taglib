// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// Junk before or after an MPEG stream without a Xing header is searched through for the first and
/// last frames, and moves them by exactly its own length.
@Suite
struct MPEGFrameScanTests {
    /// 100 MPEG-1 Layer III frames, 128 kbps at 44.1 kHz: 417 bytes each, no padding.
    private static let frames: Data = {
        let frame = Data([0xFF, 0xFB, 0x90, 0x00]) + Data(count: 413)
        return (0 ..< 100).reduce(into: Data()) { data, _ in data += frame }
    }()

    private static let junk = Data(count: 1 << 20)

    private func layout(of data: Data) throws -> MpegFrameLayout {
        let path = NSTemporaryDirectory() + "taglib-mpeg-scan-\(UUID().uuidString).mp3"
        try data.write(to: URL(fileURLWithPath: path))
        return mpegFrameLayout(path)
    }

    @Test func junkAfterTheStreamLeavesTheFramesWhereTheyAre() throws {
        let clean = try layout(of: Self.frames)
        try #require(clean.firstFrameOffset == 0 && clean.lengthInMilliseconds > 0)

        let tail = try layout(of: Self.frames + Self.junk)

        #expect(tail.firstFrameOffset == clean.firstFrameOffset)
        #expect(tail.lastFrameOffset == clean.lastFrameOffset)
        #expect(tail.lengthInMilliseconds == clean.lengthInMilliseconds)
    }

    @Test func junkBeforeTheStreamMovesTheFramesByItsLength() throws {
        let clean = try layout(of: Self.frames)
        let lead = try layout(of: Self.junk + Self.frames)
        let shift = Int64(Self.junk.count)

        #expect(lead.firstFrameOffset == clean.firstFrameOffset + shift)
        #expect(lead.lastFrameOffset == clean.lastFrameOffset + shift)
        #expect(lead.lengthInMilliseconds == clean.lengthInMilliseconds)
    }
}
