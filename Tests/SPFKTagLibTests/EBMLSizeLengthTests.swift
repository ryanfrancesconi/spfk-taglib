// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-taglib

import Foundation
import TagLibTestHelper
import Testing

/// An EBML size of length n carries 7n value bits, and all of them set means "unknown size", so the
/// largest size it holds is 2^(7n) - 2. Each length from 1 to 8 must be chosen at that boundary.
@Suite
struct EBMLSizeLengthTests {
    static let lengths = Array(1 ... 8)

    /// 2^(7n) - 1, the "unknown size" value of length n.
    static func limit(_ length: Int) -> UInt64 {
        (UInt64(1) << UInt64(7 * length)) - 1
    }

    @Test(arguments: lengths)
    func largestSizeOfALengthUsesThatLength(length: Int) {
        var roundTrips = false
        let rendered = ebmlSizeLength(Self.limit(length) - 1, &roundTrips)
        #expect(rendered == Int32(length))
        #expect(roundTrips)
    }

    @Test(arguments: lengths.dropLast())
    func sizeAtALimitTakesTheNextLength(length: Int) {
        var roundTrips = false
        let rendered = ebmlSizeLength(Self.limit(length), &roundTrips)
        #expect(rendered == Int32(length + 1))
        #expect(roundTrips)
    }
}
