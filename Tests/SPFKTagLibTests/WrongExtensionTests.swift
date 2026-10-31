// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// `FileRef` reads a file whose content is another format than its extension names as what it is,
/// while files with no other format's signature keep the extension's parser.
@Suite
struct WrongExtensionTests {
    private struct Summary: Equatable {
        let format: String
        let propertyCount: Int
        let title: String
    }

    private func copy(_ name: String, _ ext: String, as newExt: String) throws -> URL {
        let fixture = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WrongExtension-\(UUID().uuidString).\(newExt)")
        try FileManager.default.copyItem(at: fixture, to: url)
        return url
    }

    private func summary(_ url: URL) -> Summary {
        var result = url.withUnsafeFileSystemRepresentation { fileRefSummary($0) }
        let format = withUnsafeBytes(of: &result.format) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let title = withUnsafeBytes(of: &result.title) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return Summary(format: format, propertyCount: Int(result.propertyCount), title: title)
    }

    private func setTitle(_ url: URL, _ title: String) -> Bool {
        url.withUnsafeFileSystemRepresentation { fileRefSetTitle($0, title) }
    }

    @Test(arguments: [
        ("has-tags", "m4a", "mp3"),
        ("tagged", "aiff", "mp3"),
        ("tagged", "flac", "mp3"),
        ("tagged", "wav", "aif"),
        ("tagged", "aiff", "wav"),
        // FLAC and MP4 reject Matroska, so these reach content detection after a failed parse.
        ("sample", "mkv", "flac"),
        ("sample", "mkv", "m4a"),
    ])
    func readsAsItsContent(name: String, ext: String, misnamedAs: String) throws {
        let named = summary(try copy(name, ext, as: ext))
        try #require(!named.format.isEmpty && named.propertyCount > 0)

        #expect(summary(try copy(name, ext, as: misnamedAs)) == named)
    }

    @Test(arguments: [("tagged", "flac", "fLaC", 0), ("has-tags", "m4a", "ftyp", 4)])
    func savesAsItsContent(name: String, ext: String, signature: String, offset: Int) throws {
        let url = try copy(name, ext, as: "mp3")

        #expect(setTitle(url, "Edited"))

        let data = try Data(contentsOf: url)
        #expect(data.dropFirst(offset).prefix(4) == Data(signature.utf8))
        #expect(summary(url).format == summary(try copy(name, ext, as: ext)).format)
        #expect(summary(url).title == "Edited")
    }

    @Test(arguments: ["mp3", "aac"])
    func emptyFileKeepsTheMPEGParser(ext: String) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WrongExtension-\(UUID().uuidString).\(ext)")
        try Data().write(to: url)

        #expect(summary(url).format == "MPEG")
        #expect(setTitle(url, "Edited"))
        #expect(summary(url) == Summary(format: "MPEG", propertyCount: 1, title: "Edited"))
    }

    /// RIFF-wrapped MP3 with an ID3v1 after the RIFF data, which only the MPEG parser reads.
    @Test func mpegInWaveKeepsTheMPEGParser() throws {
        let url = try copy("mpeg-in-wave", "wav", as: "mp3")

        #expect(summary(url) == Summary(format: "MPEG", propertyCount: 1, title: "RIFF MP3 Title"))
    }
}
