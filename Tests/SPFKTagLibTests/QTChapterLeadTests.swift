// Copyright Ryan Francesconi. All Rights Reserved.

import AVFoundation
import Foundation
import TagLibTestHelper
import Testing

/// A QuickTime chapter list whose first chapter starts after zero covers the gap with an empty edit,
/// so a player that honors the edit list shows only the chapters written.
@Suite
struct QTChapterLeadTests {
    private func copy() throws -> URL {
        let source = try #require(Bundle.module.url(forResource: "has-tags", withExtension: "m4a", subdirectory: "Resources"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qt-chapter-lead-\(UUID().uuidString).m4a")
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    @Test func aFirstChapterAfterZeroIsTheFirstChapterAVFoundationLists() async throws {
        let url = try copy()
        defer { try? FileManager.default.removeItem(at: url) }

        let times: [Int64] = [500, 1000]
        let titles = ["First", "Second"]
        let written = titles.withCStringArray { pointers in
            url.withUnsafeFileSystemRepresentation { path in path.map { qtChapterWrite($0, 2, times, pointers) } ?? false }
        }
        try #require(written)

        let asset = AVURLAsset(url: url)
        let groups = try await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: ["und"])
        var listed: [String] = []
        for group in groups {
            listed.append(try await group.items.first?.load(.stringValue) ?? "")
        }

        #expect(listed == titles)
        #expect(groups.first.map { abs($0.timeRange.start.seconds - 0.5) < 0.001 } == true)

        // TagLib's own reader still finds the chapters at their times.
        let read = url.withUnsafeFileSystemRepresentation { path in path.map { qtChapterRead($0) } }
        #expect(read?.count == 2)
        #expect(read?.startTimesMs.0 == 500)
        #expect(read?.startTimesMs.1 == 1000)
    }
}
