// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// `setProperties` keeps the frames a key is spread over, such as one undescribed COMM per
/// language, when the requested list equals their combined values.
@Suite
struct ID3v2SpreadFrameTests {
    private struct Comment: Equatable {
        let language: String
        let text: String
    }

    private struct Frames {
        let comments: [Comment]
        let userTextCount: Int
    }

    private static func setComment(_ values: [String]?) -> Frames {
        let languages = ["eng", "deu"]
        let texts = ["hello", "hallo"]

        let result = languages.withCStringArray { languagePointers in
            texts.withCStringArray { textPointers in
                if let values {
                    values.withCStringArray { valuePointers in
                        id3v2SetComment(2, languagePointers, textPointers, Int32(values.count), valuePointers)
                    }
                } else {
                    id3v2SetComment(2, languagePointers, textPointers, 0, nil)
                }
            }
        }

        let stored = withUnsafeBytes(of: result.languages) { languages in
            withUnsafeBytes(of: result.texts) { texts in
                (0 ..< min(Int(result.commentCount), 4)).map { index in
                    Comment(
                        language: string(languages, offset: index * 4, length: 4),
                        text: string(texts, offset: index * 32, length: 32)
                    )
                }
            }
        }

        return Frames(comments: stored, userTextCount: Int(result.userTextCount))
    }

    private static func string(_ raw: UnsafeRawBufferPointer, offset: Int, length: Int) -> String {
        String(decoding: raw[offset ..< offset + length].prefix { $0 != 0 }, as: UTF8.self)
    }

    @Test func ownPropertiesKeepEveryFrame() {
        let frames = Self.setComment(nil)
        #expect(frames.comments == [Comment(language: "eng", text: "hello"), Comment(language: "deu", text: "hallo")])
        #expect(frames.userTextCount == 0)
    }

    @Test func oneFramesValueKeepsThatFrame() {
        let frames = Self.setComment(["hello"])
        #expect(frames.comments == [Comment(language: "eng", text: "hello")])
        #expect(frames.userTextCount == 0)
    }

    @Test func aChangedListIsOneUserTextFrame() {
        let frames = Self.setComment(["a", "b"])
        #expect(frames.comments.isEmpty)
        #expect(frames.userTextCount == 1)
    }
}
