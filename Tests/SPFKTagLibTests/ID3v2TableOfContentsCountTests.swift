// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-taglib

import Foundation
import TagLibTestHelper
import Testing

/// A `CTOC` stores its entry count in one byte, so it renders at most 255 child elements, with a count
/// that matches, and the embedded frames after them still parse.
@Suite
struct ID3v2TableOfContentsCountTests {
    @Test(arguments: [1, 255])
    func aCountThatFitsRoundTrips(childCount: Int) {
        var parsed: Int32 = -1
        var titleParsed = false
        id3v2TableOfContentsRoundTrip(Int32(childCount), &parsed, &titleParsed)
        #expect(parsed == Int32(childCount))
        #expect(titleParsed)
    }

    @Test(arguments: [256, 300, 600])
    func aCountPastOneByteRendersTheFirst255(childCount: Int) {
        var parsed: Int32 = -1
        var titleParsed = false
        id3v2TableOfContentsRoundTrip(Int32(childCount), &parsed, &titleParsed)
        #expect(parsed == 255)
        #expect(titleParsed)
    }
}
