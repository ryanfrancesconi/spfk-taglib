// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// DISP chunks are read and written as raw payloads in file order, and rewritten only when set.
@Suite
struct WAVDISPChunkTests {
    private func makeCopy() -> String {
        let path = NSTemporaryDirectory() + "taglib-disp-\(UUID().uuidString).wav"
        #expect(copyTestFile(RF64Tests.fixtureURL.path, path))
        return path
    }

    private func setTexts(_ texts: [String], at path: String) -> Bool {
        var pointers = texts.map { strdup($0) }
        defer { pointers.forEach { free($0) } }
        return pointers.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return wavSetDISPTexts(path, nil, 0) }
            return base.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) {
                wavSetDISPTexts(path, $0, Int32(texts.count))
            }
        }
    }

    private func text(at index: Int32, in path: String) -> (format: Int32, text: String) {
        var buffer = [CChar](repeating: 0, count: 256)
        let format = wavDISPText(path, index, &buffer, 256)
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return (format, String(decoding: bytes, as: UTF8.self))
    }

    @Test func roundTripsChunksInOrder() {
        let path = makeCopy()
        #expect(wavDISPCount(path) == 0)

        #expect(setTexts(["Station ID", "Second"], at: path))

        #expect(wavDISPCount(path) == 2)
        #expect(text(at: 0, in: path) == (1, "Station ID"))
        #expect(text(at: 1, in: path) == (1, "Second"))
    }

    @Test func aSaveThatDoesNotSetDISPKeepsIt() {
        let path = makeCopy()
        #expect(setTexts(["Station ID"], at: path))

        #expect(wavWriteProperties(path, "Title", "Artist"))

        #expect(wavDISPCount(path) == 1)
        #expect(text(at: 0, in: path) == (1, "Station ID"))
    }

    @Test func anEmptyListRemovesEveryChunk() {
        let path = makeCopy()
        #expect(setTexts(["Station ID", "Second"], at: path))

        #expect(setTexts([], at: path))

        #expect(wavDISPCount(path) == 0)
    }
}
