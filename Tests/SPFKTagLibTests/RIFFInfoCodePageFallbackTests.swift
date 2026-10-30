// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// A field that is not valid UTF-8 under an *assumed* UTF-8 reads as Latin-1; a *declared* UTF-8 is
/// never second-guessed.
@Suite
struct RIFFInfoCodePageFallbackTests {
    private let utf8CodePage: UInt32 = 65001

    private func decode(_ bytes: [UInt8], declared: UInt32, assumed: UInt32) -> String {
        var out = [CChar](repeating: 0, count: 256)
        bytes.withUnsafeBufferPointer { buffer in
            buffer.withMemoryRebound(to: CChar.self) { chars in
                _ = infoDecodedField(chars.baseAddress, UInt32(bytes.count), declared, assumed, &out, Int32(out.count))
            }
        }
        return String(decoding: out.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// `© 2019 BOOM` in Latin-1, as Soundminer writes it with no CSET.
    private let latin1Copyright: [UInt8] = [0xA9] + Array(" 2019 BOOM".utf8) + [0]

    @Test func assumedUTF8FallsBackToLatin1ForInvalidBytes() {
        #expect(decode(latin1Copyright, declared: 0, assumed: utf8CodePage) == "© 2019 BOOM")
    }

    @Test func assumedUTF8StillDecodesValidUTF8() {
        let bytes = Array("© 2019 Café".utf8) + [0]
        #expect(decode(bytes, declared: 0, assumed: utf8CodePage) == "© 2019 Café")
    }

    @Test func declaredUTF8DoesNotFallBack() {
        #expect(decode(latin1Copyright, declared: utf8CodePage, assumed: utf8CodePage) == "")
        #expect(decode(latin1Copyright, declared: utf8CodePage, assumed: 0) == "")
    }
}
