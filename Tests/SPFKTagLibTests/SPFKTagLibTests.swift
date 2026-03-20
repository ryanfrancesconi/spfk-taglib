// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

@Suite(.serialized)
final class MP4QTChapterTests {
    /// Path to the bundled test M4A resource.
    static let resourceURL: URL = {
        Bundle.module.url(forResource: "has-tags", withExtension: "m4a", subdirectory: "Resources")!
    }()

    /// Creates a temporary copy of the test file, returning its path.
    func makeTempCopy() throws -> String {
        let tmp = NSTemporaryDirectory() + "taglib-qt-chapter-\(UUID().uuidString).m4a"
        #expect(copyTestFile(Self.resourceURL.path, tmp))
        return tmp
    }

    // MARK: - Write and read round-trip

    @Test func writeAndReadChapters() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let times: [Int64] = [0, 1500, 3000]
        let titles: [String] = ["Intro", "Verse", "Outro"]

        let ok = titles.withCStringArray { ptrs in
            qtChapterWrite(path, 3, times, ptrs)
        }
        #expect(ok, "Write should succeed")

        let result = qtChapterRead(path)
        #expect(result.count == 3)
        #expect(result.startTimesMs.0 == 0)
        #expect(result.startTimesMs.1 == 1500)
        #expect(result.startTimesMs.2 == 3000)
        #expect(String(cString: tuplePointer(to: result.titles.0)) == "Intro")
        #expect(String(cString: tuplePointer(to: result.titles.1)) == "Verse")
        #expect(String(cString: tuplePointer(to: result.titles.2)) == "Outro")
    }

    // MARK: - Remove chapters

    @Test func removeChapters() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Write some chapters first
        let times: [Int64] = [0, 1000]
        let titles = ["Ch1", "Ch2"]
        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 2, times, ptrs)
        }
        #expect(qtChapterRead(path).count == 2)

        // Remove
        #expect(qtChapterRemove(path))
        #expect(qtChapterRead(path).count == 0)
    }

    // MARK: - Read from file with no chapters

    @Test func readFromFileWithNoChapters() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let result = qtChapterRead(path)
        #expect(result.count == 0)
    }

    // MARK: - Overwrite existing chapters

    @Test func overwriteExistingChapters() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Write initial chapters
        let times1: [Int64] = [0, 500]
        let titles1 = ["Old1", "Old2"]
        titles1.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 2, times1, ptrs)
        }
        #expect(qtChapterRead(path).count == 2)

        // Overwrite with different chapters
        let times2: [Int64] = [0, 1000, 2000]
        let titles2 = ["New1", "New2", "New3"]
        titles2.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 3, times2, ptrs)
        }

        let result = qtChapterRead(path)
        #expect(result.count == 3)
        #expect(String(cString: tuplePointer(to: result.titles.0)) == "New1")
        #expect(String(cString: tuplePointer(to: result.titles.1)) == "New2")
        #expect(String(cString: tuplePointer(to: result.titles.2)) == "New3")
    }

    // MARK: - Timestamp precision

    @Test func timestampPrecision() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let times: [Int64] = [0, 1500]
        let titles = ["Start", "Precise"]
        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 2, times, ptrs)
        }

        let result = qtChapterRead(path)
        #expect(result.count == 2)
        #expect(result.startTimesMs.0 == 0)
        #expect(result.startTimesMs.1 == 1500)
    }

    // MARK: - Non-zero first chapter preserves absolute times

    @Test func nonZeroFirstChapterRoundTrip() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Markers at 1s, 2s, 3s — first chapter is NOT at time 0
        let times: [Int64] = [1000, 2000, 3000]
        let titles = ["One", "Two", "Three"]
        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 3, times, ptrs)
        }

        let result = qtChapterRead(path)
        #expect(result.count == 3)
        #expect(result.startTimesMs.0 == 1000)
        #expect(result.startTimesMs.1 == 2000)
        #expect(result.startTimesMs.2 == 3000)
        #expect(String(cString: tuplePointer(to: result.titles.0)) == "One")
        #expect(String(cString: tuplePointer(to: result.titles.1)) == "Two")
        #expect(String(cString: tuplePointer(to: result.titles.2)) == "Three")
    }

    // MARK: - Inspection (writes to /tmp for manual verification)

    @Test func writeChaptersForInspection() throws {
        let path = "/tmp/chapter_test_output.m4a"
        #expect(copyTestFile(Self.resourceURL.path, path))

        let times: [Int64] = [1000, 2000, 3000]
        let titles = ["One", "Two", "Three"]
        let ok = titles.withCStringArray { ptrs in
            qtChapterWrite(path, 3, times, ptrs)
        }
        #expect(ok, "Write should succeed")
    }

    // MARK: - File size changes after write

    @Test func fileSizeChangesAfterWrite() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let sizeBefore = testFileSize(path)
        #expect(sizeBefore > 0)

        let times: [Int64] = [0]
        let titles = ["Only"]
        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 1, times, ptrs)
        }

        let sizeAfter = testFileSize(path)
        #expect(sizeAfter != sizeBefore, "File size should change after writing chapters")
        #expect(sizeAfter > sizeBefore, "File should grow when adding chapters to a file without them")
    }
}

// MARK: - Helpers

/// Helper to get a pointer to a fixed-size C char tuple for use with String(cString:).
private func tuplePointer(to tuple: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                     CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                     CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                     CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                     CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                     CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                     CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                                     CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)
) -> UnsafePointer<CChar> {
    withUnsafePointer(to: tuple) { ptr in
        UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self)
    }
}

extension Array where Element == String {
    /// Calls `body` with a mutable array of C string pointers. The pointers are
    /// valid only for the duration of the closure.
    @discardableResult
    func withCStringArray<R>(_ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>) -> R) -> R {
        let cStrings = self.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }
        var ptrs = cStrings.map { UnsafePointer<CChar>($0) as UnsafePointer<CChar>? }
        return ptrs.withUnsafeMutableBufferPointer { buffer in
            body(buffer.baseAddress!)
        }
    }
}
