// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// `setProperties` updates the one frame holding an edited key in place, keeping its language,
/// description, position and encoding.
@Suite
struct ID3v2EditInPlaceTests {
    private static let latin1: Int32 = 0
    private static let utf8: Int32 = 3

    private struct Spec {
        let id: String
        var language: String?
        var description: String?
        let text: String
        var encoding: Int32 = ID3v2EditInPlaceTests.utf8
    }

    private struct Frame: Equatable {
        let id: String
        var language = ""
        var description = ""
        let text: String
        var encoding: Int32 = ID3v2EditInPlaceTests.utf8
    }

    private static func setProperty(_ specs: [Spec], key: String, values: [String]?) -> [Frame] {
        var allocated: [UnsafeMutablePointer<CChar>] = []
        defer { allocated.forEach { free($0) } }

        func cString(_ string: String?) -> UnsafePointer<CChar>? {
            guard let string, let pointer = strdup(string) else { return nil }
            allocated.append(pointer)
            return UnsafePointer(pointer)
        }

        let cSpecs = specs.map {
            ID3v2FrameSpec(
                frameID: cString($0.id),
                language: cString($0.language),
                description: cString($0.description),
                text: cString($0.text),
                encoding: $0.encoding
            )
        }

        let result = key.withCString { cKey in
            if let values {
                values.withCStringArray { valuePointers in
                    id3v2SetProperty(Int32(cSpecs.count), cSpecs, cKey, Int32(values.count), valuePointers)
                }
            } else {
                id3v2SetProperty(Int32(cSpecs.count), cSpecs, cKey, 0, nil)
            }
        }

        return withUnsafeBytes(of: result.frames) { raw in
            raw.bindMemory(to: ID3v2FrameState.self).prefix(Int(result.frameCount)).map { state in
                Frame(
                    id: string(state.frameID),
                    language: string(state.language),
                    description: string(state.description),
                    text: string(state.text),
                    encoding: state.encoding
                )
            }
        }
    }

    private static func string<T>(_ tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    // MARK: - Edited in place

    @Test func anEditedCommentKeepsItsLanguage() {
        let frames = Self.setProperty(
            [Spec(id: "COMM", language: "deu", text: "hallo")],
            key: "COMMENT", values: ["tschüss"]
        )
        #expect(frames == [Frame(id: "COMM", language: "deu", text: "tschüss")])
    }

    @Test func editedLyricsKeepTheirLanguage() {
        let frames = Self.setProperty(
            [Spec(id: "USLT", language: "fra", text: "la")],
            key: "LYRICS", values: ["la la"]
        )
        #expect(frames == [Frame(id: "USLT", language: "fra", text: "la la")])
    }

    @Test func anEditedUserTextKeepsItsDescription() {
        let frames = Self.setProperty(
            [Spec(id: "TXXX", description: "MyTag", text: "old")],
            key: "MYTAG", values: ["new"]
        )
        #expect(frames == [Frame(id: "TXXX", description: "MyTag", text: "new")])
    }

    @Test func anEditedKnownUserTextKeepsItsDescription() {
        let frames = Self.setProperty(
            [Spec(id: "TXXX", description: "MusicBrainz Album Id", text: "old")],
            key: "MUSICBRAINZ_ALBUMID", values: ["new"]
        )
        #expect(frames == [Frame(id: "TXXX", description: "MusicBrainz Album Id", text: "new")])
    }

    @Test func anEditedFrameKeepsItsPosition() {
        let frames = Self.setProperty(
            [
                Spec(id: "TIT2", text: "title"),
                Spec(id: "TPE1", text: "artist"),
                Spec(id: "WOAR", text: "https://a.example"),
                Spec(id: "COMM", language: "eng", text: "comment"),
            ],
            key: "TITLE", values: ["new title"]
        )
        #expect(frames.map(\.id) == ["TIT2", "TPE1", "WOAR", "COMM"])
        #expect(frames.first?.text == "new title")
    }

    @Test func anEditedURLKeepsItsPosition() {
        let frames = Self.setProperty(
            [
                Spec(id: "WOAR", text: "https://a.example"),
                Spec(id: "TIT2", text: "title"),
            ],
            key: "ARTISTWEBPAGE", values: ["https://b.example"]
        )
        #expect(frames.map(\.id) == ["WOAR", "TIT2"])
        #expect(frames.first?.text == "https://b.example")
    }

    @Test func anEditedLatin1FrameKeepsItsEncoding() {
        let frames = Self.setProperty(
            [Spec(id: "TIT2", text: "title", encoding: Self.latin1)],
            key: "TITLE", values: ["new title"]
        )
        #expect(frames == [Frame(id: "TIT2", text: "new title", encoding: Self.latin1)])
    }

    // MARK: - Delete and create, as before

    @Test func aKeySpreadOverTwoFramesIsReplaced() {
        let frames = Self.setProperty(
            [
                Spec(id: "COMM", language: "eng", text: "hello"),
                Spec(id: "COMM", language: "deu", text: "hallo"),
            ],
            key: "COMMENT", values: ["x"]
        )
        #expect(frames == [Frame(id: "COMM", text: "x")])
    }

    @Test func aListACommentCannotHoldBecomesUserText() {
        let frames = Self.setProperty(
            [Spec(id: "COMM", language: "deu", text: "hallo")],
            key: "COMMENT", values: ["a", "b"]
        )
        #expect(frames == [Frame(id: "TXXX", description: "COMMENT", text: "a/b")])
    }

    @Test func aRemovedKeyDeletesItsFrame() {
        let frames = Self.setProperty(
            [
                Spec(id: "TIT2", text: "title"),
                Spec(id: "COMM", language: "deu", text: "hallo"),
            ],
            key: "COMMENT", values: nil
        )
        #expect(frames == [Frame(id: "TIT2", text: "title")])
    }
}
