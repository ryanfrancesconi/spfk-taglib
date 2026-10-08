// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-taglib

import Foundation
import TagLibTestHelper
import Testing

/// A save that grows the `Tags` ahead of the cluster and adds the file's first attachment leaves a
/// Segment whose elements run contiguously to its declared end, whichever write style it uses.
@Suite
struct MatroskaAvoidInsertTests {
    /// Longer than any padding the fixture's `Tags` has, so the element grows.
    static let title = String(repeating: "Avoid insert ", count: 200)
    static let attachment = Data((0 ..< 4096).map { UInt8(truncatingIfNeeded: $0 &* 31) })

    @Test(arguments: [false, true])
    func aGrownTagAndANewAttachmentLeaveAValidSegment(avoidInsert: Bool) throws {
        guard let fixture = Bundle.module.url(forResource: "sample", withExtension: "mkv", subdirectory: "Resources") else {
            Issue.record("sample.mkv missing from the test bundle")
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MatroskaAvoidInsert-\(UUID().uuidString).mkv")
        try FileManager.default.copyItem(at: fixture, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let before = url.withUnsafeFileSystemRepresentation { path in path.map { mkvSegmentLayout($0) } }
        try #require(before?.contiguous == true)
        try #require(url.withUnsafeFileSystemRepresentation { path in path.map { mkvAttachedFileCount($0) } } == 0)

        let saved = url.withUnsafeFileSystemRepresentation { path in
            path.map { path in
                Self.attachment.withUnsafeBytes { bytes in
                    mkvSetPropertyAndAttach(path, "TITLE", Self.title, bytes.baseAddress, UInt32(bytes.count), avoidInsert)
                }
            } ?? false
        }
        #expect(saved)

        let after = try #require(url.withUnsafeFileSystemRepresentation { path in path.map { mkvSegmentLayout($0) } })
        #expect(after.contiguous)
        #expect(after.segmentEnd == after.fileSize)

        if avoidInsert {
            #expect(after.firstClusterOffset == before?.firstClusterOffset)
        }

        #expect(url.withUnsafeFileSystemRepresentation { path in path.map { mkvAttachedFileCount($0) } } == 1)

        var buffer = [CChar](repeating: 0, count: Self.title.utf8.count + 1)
        let readLength = url.withUnsafeFileSystemRepresentation { path in
            path.map { mkvReadProperty($0, "TITLE", &buffer, Int64(buffer.count)) } ?? -1
        }
        #expect(readLength == Int64(Self.title.utf8.count))
    }
}
