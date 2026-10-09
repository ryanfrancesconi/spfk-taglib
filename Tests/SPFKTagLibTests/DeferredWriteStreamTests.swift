// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-taglib

import Foundation
import TagLibTestHelper
import Testing

/// `DeferredWriteStream` reads as the edits it has recorded, commits to exactly that content, and
/// writes only what moved or changed.
@Suite
struct DeferredWriteStreamTests {
    /// A file of `count` patterned bytes, so a moved range never reads back as unchanged.
    private func file(_ count: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DeferredWriteStream-\(UUID().uuidString).bin")
        var state: UInt32 = 0x1357_9BDF
        let bytes = (0 ..< count).map { _ -> UInt8 in
            state = state &* 1_664_525 &+ 1_013_904_223
            return UInt8(truncatingIfNeeded: state >> 24)
        }
        try Data(bytes).write(to: url)
        return url
    }

    @Test(arguments: 0 ..< 200)
    func randomEditsMatchAnInMemoryStream(seed: Int) throws {
        let url = try file(20000)
        let copy = try file(1)
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: copy)
        }

        let result = url.withUnsafeFileSystemRepresentation { path in
            copy.withUnsafeFileSystemRepresentation { copyPath in
                guard let path, let copyPath else { return 0 }
                return Int(deferredStreamFuzz(path, copyPath, UInt32(seed), 24))
            }
        }
        #expect(result == -1, "seed \(seed) diverged after operation \(result)")
    }

    /// Growing a block near the start and shrinking one further on moves only the bytes between
    /// them; the rest of the file keeps its place and is not written.
    @Test func aCommitWritesOnlyWhatMoved() throws {
        let url = try file(1 << 20)
        defer { try? FileManager.default.removeItem(at: url) }

        let written = url.withUnsafeFileSystemRepresentation { path in
            path.map { deferredStreamCommitBytes($0, 100, 16, 4116, 16) } ?? -1
        }
        // 16 inserted bytes, then the 4,000 between the insertion and the removal moved by 16.
        let expected: Int64 = 16 + 4000
        #expect(written == expected)
    }

    @Test func aGrowthMovesTheRestOnce() throws {
        let url = try file(1 << 20)
        defer { try? FileManager.default.removeItem(at: url) }

        let written = url.withUnsafeFileSystemRepresentation { path in
            path.map { deferredStreamCommitBytes($0, 100, 16, 200, 0) } ?? -1
        }
        let expected: Int64 = 16 + (1 << 20) - 100
        #expect(written == expected)
    }

    /// Overwriting and appending leave every original byte where it was; inserting or removing at 100
    /// moves the 900 or 884 bytes after the edit.
    @Test(arguments: [(0, 0), (1, 0), (2, 900), (3, 884)])
    func bytesToMoveCountsWhatAnEditDisplaces(edit: Int, moved: Int) throws {
        let url = try file(1000)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.withUnsafeFileSystemRepresentation { path in path.map { deferredStreamBytesToMove($0, Int32(edit)) } ?? -1 } == Int64(moved))
    }

    @Test func aReadOnlyStreamRefusesToCommit() throws {
        let url = try file(1000)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.withUnsafeFileSystemRepresentation { path in path.map { deferredStreamRefusesReadOnlyCommit($0) } ?? false })
    }
}
