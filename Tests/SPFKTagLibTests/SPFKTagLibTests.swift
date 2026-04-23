// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

// MARK: - QT Chapter Tests

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

    // MARK: - No orphaned mdat atoms after repeated write/remove cycles
    //
    // Regression test for PR #1325 / commit 7b7b5ebd:
    // Before the fix, each add/remove cycle left behind an orphaned mdat atom
    // containing the chapter text track data. Three cycles produced
    // baseMdat + 3 atoms. After the fix, mdat count must stay constant.

    @Test func noOrphanedMdatRegressionTest() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let baseMdat = countMdatAtoms(path)
        #expect(baseMdat >= 1, "Test file must have at least one mdat atom")

        let times: [Int64] = [0, 10000]
        let titles = ["Chapter 1", "Chapter 2"]

        for _ in 0..<3 {
            titles.withCStringArray { ptrs in
                _ = qtChapterWrite(path, 2, times, ptrs)
            }
            #expect(qtChapterRemove(path))
        }

        // After all cycles: mdat count must be unchanged — no orphans
        #expect(countMdatAtoms(path) == baseMdat,
                "Orphaned mdat atoms detected: remove did not clean up chapter mdat")
    }

    // MARK: - Primary audio mdat is untouched after chapter remove
    //
    // Verifies the fix from commit 41cfbfe0:
    // Removing a QT chapter track must not delete the audio mdat.
    // The first mdat in the file is the audio mdat; its size must survive
    // a write/remove cycle intact.

    @Test func audioMdatSizePreservedAfterChapterRemove() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let audioMdatSizeBefore = firstMdatSize(path)
        #expect(audioMdatSizeBefore > 0, "Test file must have an audio mdat atom")

        // Write a chapter track (appends a separate chapter mdat at EOF)
        let times: [Int64] = [0, 5000]
        let titles = ["A", "B"]
        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 2, times, ptrs)
        }

        // Remove the chapter track
        #expect(qtChapterRemove(path))

        // The audio mdat must be the same size as before
        let audioMdatSizeAfter = firstMdatSize(path)
        #expect(audioMdatSizeAfter == audioMdatSizeBefore,
                "Audio mdat size changed after chapter remove: possible data corruption")
    }

    // MARK: - Unicode titles round-trip

    @Test func unicodeTitleRoundTrip() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let times: [Int64] = [0, 1000, 2000]
        let titles = ["第一章", "🎵 Beat Drop", "Ünïcödé"]

        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 3, times, ptrs)
        }

        let result = qtChapterRead(path)
        #expect(result.count == 3)
        #expect(String(cString: tuplePointer(to: result.titles.0)) == "第一章")
        #expect(String(cString: tuplePointer(to: result.titles.1)) == "🎵 Beat Drop")
        #expect(String(cString: tuplePointer(to: result.titles.2)) == "Ünïcödé")
    }

    // MARK: - Empty title at t=0 is stripped (documented limitation)
    //
    // When writing two or more chapters with an empty-title first chapter at t=0,
    // read() strips it — it's indistinguishable from the dummy chapter inserted
    // by write() to preserve non-zero start times.
    // Single-chapter case is NOT stripped (only 1 chapter, stripping would leave empty list).

    @Test func emptyTitleAtZeroIsStrippedWhenMultipleChapters() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Two chapters: first has empty title at t=0
        let times: [Int64] = [0, 1000]
        let titles = ["", "Chapter 2"]
        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 2, times, ptrs)
        }

        // The empty-title chapter at t=0 is stripped on read-back
        let result = qtChapterRead(path)
        #expect(result.count == 1, "Empty-title first chapter at t=0 should be stripped")
        #expect(String(cString: tuplePointer(to: result.titles.0)) == "Chapter 2")
        #expect(result.startTimesMs.0 == 1000)
    }

    @Test func singleEmptyTitleChapterAtZeroIsNotStripped() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // A single chapter with empty title is NOT stripped (nothing left if it were)
        let times: [Int64] = [0]
        let titles = [""]
        titles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 1, times, ptrs)
        }

        let result = qtChapterRead(path)
        #expect(result.count == 1, "Single empty-title chapter should not be stripped")
        #expect(result.startTimesMs.0 == 0)
    }
}

// MARK: - Nero Chapter Tests

@Suite(.serialized)
final class MP4NeroChapterTests {
    static let resourceURL: URL = {
        Bundle.module.url(forResource: "has-tags", withExtension: "m4a", subdirectory: "Resources")!
    }()

    func makeTempCopy() throws -> String {
        let tmp = NSTemporaryDirectory() + "taglib-nero-chapter-\(UUID().uuidString).m4a"
        #expect(copyTestFile(Self.resourceURL.path, tmp))
        return tmp
    }

    // MARK: - Write and read round-trip

    @Test func writeAndRead() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let times: [Int64] = [0, 1500, 3000]
        let titles = ["Intro", "Verse", "Outro"]

        let ok = titles.withCStringArray { ptrs in
            neroChapterWrite(path, 3, times, ptrs)
        }
        #expect(ok, "Nero chapter write should succeed")

        let result = neroChapterRead(path)
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

        let times: [Int64] = [0, 1000]
        let titles = ["Ch1", "Ch2"]
        titles.withCStringArray { ptrs in
            _ = neroChapterWrite(path, 2, times, ptrs)
        }
        #expect(neroChapterRead(path).count == 2)

        #expect(neroChapterRemove(path))
        #expect(neroChapterRead(path).count == 0)
    }

    // MARK: - Read from file with no chapters

    @Test func readEmpty() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // File has no Nero chapters initially
        #expect(neroChapterRead(path).count == 0)
    }

    // MARK: - Nero chapters coexist without disturbing QT chapters

    @Test func neroAndQTChaptersAreIndependent() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // Write QT chapters
        let qtTimes: [Int64] = [0, 2000]
        let qtTitles = ["QT1", "QT2"]
        qtTitles.withCStringArray { ptrs in
            _ = qtChapterWrite(path, 2, qtTimes, ptrs)
        }

        // Write Nero chapters independently
        let neroTimes: [Int64] = [0, 1000, 2000]
        let neroTitles = ["N1", "N2", "N3"]
        neroTitles.withCStringArray { ptrs in
            _ = neroChapterWrite(path, 3, neroTimes, ptrs)
        }

        // Both should be readable
        let qt = qtChapterRead(path)
        let nero = neroChapterRead(path)
        #expect(qt.count == 2, "QT chapters should survive Nero write")
        #expect(nero.count == 3, "Nero chapters should be present")
    }

    // MARK: - Nero-only: QT track stays empty when only Nero chapters are written

    @Test func neroChaptersAloneWhenNoQT() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let times: [Int64] = [0, 3000, 6000]
        let titles = ["Intro", "Body", "Outro"]
        titles.withCStringArray { ptrs in
            _ = neroChapterWrite(path, 3, times, ptrs)
        }

        // QT chapter track should be absent
        let qt = qtChapterRead(path)
        #expect(qt.count == 0, "Writing Nero chapters should not create a QT chapter track")

        // Nero chapters should be readable
        let nero = neroChapterRead(path)
        #expect(nero.count == 3)
        #expect(nero.startTimesMs.0 == 0)
        #expect(nero.startTimesMs.1 == 3000)
        #expect(nero.startTimesMs.2 == 6000)
    }

    // MARK: - Unicode titles round-trip (Nero)

    @Test func neroUnicodeTitleRoundTrip() throws {
        let path = try makeTempCopy()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let times: [Int64] = [0, 1000, 2000]
        let titles = ["第一章", "🎵 Beat Drop", "Ünïcödé"]

        titles.withCStringArray { ptrs in
            _ = neroChapterWrite(path, 3, times, ptrs)
        }

        let result = neroChapterRead(path)
        #expect(result.count == 3)
        #expect(String(cString: tuplePointer(to: result.titles.0)) == "第一章")
        #expect(String(cString: tuplePointer(to: result.titles.1)) == "🎵 Beat Drop")
        #expect(String(cString: tuplePointer(to: result.titles.2)) == "Ünïcödé")
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
