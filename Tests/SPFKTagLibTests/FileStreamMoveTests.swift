// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-taglib

import Foundation
import TagLibTestHelper
import Testing

/// `FileStream::insert` and `removeBlock` move the rest of the file through a buffer whose size
/// `setMoveBufferSize` sets; the bytes that result must not depend on it.
@Suite
struct FileStreamMoveTests {
    /// 0 is the default. 1 and 7 force many blocks and an unaligned last one; 1 MiB holds the file.
    static let moveBufferSizes: [UInt32] = [0, 1, 7, 1024, 4096, 1 << 20]

    static let fileLength = 10_000

    struct Edit: CustomStringConvertible, Sendable {
        let description: String
        let start: Int
        let replace: Int
        /// nil for `removeBlock`.
        let insertLength: Int?
    }

    static let edits: [Edit] = [
        Edit(description: "insert growing by more than the default buffer", start: 2500, replace: 100, insertLength: 3000),
        Edit(description: "insert at the start", start: 0, replace: 0, insertLength: 10),
        Edit(description: "insert near the end", start: 9990, replace: 5, insertLength: 50),
        Edit(description: "insert shrinking", start: 100, replace: 2000, insertLength: 10),
        Edit(description: "insert the same size", start: 5000, replace: 300, insertLength: 300),
        Edit(description: "remove from the middle", start: 4000, replace: 3000, insertLength: nil),
        Edit(description: "remove the tail", start: 6000, replace: 4000, insertLength: nil),
    ]

    @Test(arguments: edits, moveBufferSizes)
    func resultIsIndependentOfTheMoveBuffer(edit: Edit, moveBufferSize: UInt32) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FileStreamMove-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }

        let original = Self.patterned(count: Self.fileLength, seed: 1)
        try original.write(to: url)

        let inserted = edit.insertLength.map { Self.patterned(count: $0, seed: 2) }
        let succeeded = url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            if let inserted {
                return inserted.withUnsafeBytes {
                    streamInsert(path, $0.baseAddress, UInt32(inserted.count), Int64(edit.start), UInt32(edit.replace), moveBufferSize)
                }
            }
            return streamRemoveBlock(path, Int64(edit.start), UInt32(edit.replace), moveBufferSize)
        }
        #expect(succeeded)

        let expected = original.prefix(edit.start) + (inserted ?? Data()) + original.dropFirst(edit.start + edit.replace)
        let result = try Data(contentsOf: url)

        #expect(result.count == expected.count)
        #expect(result == expected)
    }

    @Test func zeroRestoresTheDefault() {
        let defaultSize = streamMoveBufferSize(0)
        #expect(defaultSize == 1024)
        #expect(streamMoveBufferSize(1 << 20) == 1 << 20)
    }

    /// Not periodic at any buffer size, so a block written to the wrong place cannot match.
    private static func patterned(count: Int, seed: UInt64) -> Data {
        var state = seed &* 0x9E37_79B9_7F4A_7C15
        return Data((0 ..< count).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return UInt8(truncatingIfNeeded: state >> 33)
        })
    }
}
