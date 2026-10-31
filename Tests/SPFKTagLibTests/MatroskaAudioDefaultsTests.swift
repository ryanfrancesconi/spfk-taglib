// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// An Audio element without SamplingFrequency or Channels reads their Matroska defaults, 8000 Hz and
/// one channel. sample.mkv's video track comes first, so the audio track must still be the one read.
@Suite
struct MatroskaAudioDefaultsTests {
    /// sample.mkv's Audio element: Channels 1, SamplingFrequency as an 8-byte float, BitDepth.
    private static let audioElement = Data([0xE1, 0x91, 0x9F, 0x81, 0x01, 0xB5, 0x88])

    private func copy(voidingBitDepth: Bool?) throws -> URL {
        let fixture = try #require(Bundle.module.url(forResource: "sample", withExtension: "mkv", subdirectory: "Resources"))
        var data = try Data(contentsOf: fixture)

        if let voidingBitDepth {
            let audio = try #require(data.range(of: Self.audioElement)).lowerBound
            // Each element becomes a Void (0xEC) of the same length, so nothing else moves.
            data.replaceSubrange(audio + 2 ..< audio + 5, with: [0xEC, 0x81, 0x00])
            data.replaceSubrange(audio + 5 ..< audio + 15, with: [0xEC, 0x88] + [UInt8](repeating: 0, count: 8))
            if voidingBitDepth {
                #expect(data[audio + 15 ..< audio + 19] == Data([0x62, 0x64, 0x81, 0x20]))
                data.replaceSubrange(audio + 15 ..< audio + 19, with: [0xEC, 0x82, 0x00, 0x00])
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MatroskaAudioDefaults-\(UUID().uuidString).mkv")
        try data.write(to: url)
        return url
    }

    private func properties(_ url: URL) -> (rate: Int32, channels: Int32, codec: String) {
        var result = url.withUnsafeFileSystemRepresentation { mkvAudioProperties($0) }
        let codec = withUnsafeBytes(of: &result.codecName) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return (result.sampleRate, result.channels, codec)
    }

    @Test(arguments: [false, true])
    func absentElementsReadTheirDefaults(voidingBitDepth: Bool) throws {
        let original = properties(try copy(voidingBitDepth: nil))
        try #require(original.rate > 0 && original.rate != 8000 && !original.codec.isEmpty)

        let voided = properties(try copy(voidingBitDepth: voidingBitDepth))

        #expect(voided.rate == 8000)
        #expect(voided.channels == 1)
        #expect(voided.codec == original.codec)
    }
}
