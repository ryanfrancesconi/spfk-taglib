// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-taglib

import Foundation
import TagLibTestHelper
import Testing

/// An EBML size whose value bits are all 1 means "unknown size" (RFC 8794 § 6.2), so each size length
/// holds one less than its bit width allows. A value exactly at that limit has to take the next
/// length, or a reader runs past the element.
@Suite
struct MatroskaElementSizeTests {
    /// Each side of the one-, two- and three-byte limits: 126/127, 16382/16383, 2097150/2097151.
    static let lengths = [126, 127, 128, 16382, 16383, 16384, 2_097_150, 2_097_151]

    @Test(arguments: lengths)
    func aStringOfAnyLengthReadsBackExactly(length: Int) throws {
        guard let fixture = Bundle.module.url(forResource: "sample", withExtension: "mkv", subdirectory: "Resources") else {
            Issue.record("sample.mkv missing from the test bundle")
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MatroskaElementSize-\(UUID().uuidString).mkv")
        try FileManager.default.copyItem(at: fixture, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let value = String(repeating: "a", count: length)
        let saved = url.withUnsafeFileSystemRepresentation { path in
            path.map { mkvSetProperty($0, "SUBTITLE", value) } ?? false
        }
        #expect(saved)

        var buffer = [CChar](repeating: 0, count: length + 1)
        let readLength = url.withUnsafeFileSystemRepresentation { path in
            path.map { mkvReadProperty($0, "SUBTITLE", &buffer, Int64(buffer.count)) } ?? -1
        }

        #expect(readLength == Int64(length))
        #expect(String(cString: buffer) == value)
    }
}
