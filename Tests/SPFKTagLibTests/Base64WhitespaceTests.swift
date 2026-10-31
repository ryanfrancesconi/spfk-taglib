// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// Base64 wrapped into lines decodes as if it were not, and a Xiph picture stored that way is read
/// and kept.
@Suite
struct Base64WhitespaceTests {
    private func decode(_ input: String) -> String? {
        var buffer = [UInt8](repeating: 0, count: 256)
        let size = base64Decode(input, &buffer, 256)
        guard size >= 0 else { return nil }
        return String(decoding: buffer.prefix(Int(size)), as: UTF8.self)
    }

    @Test func lineBreaksAndSpacesAreSkipped() {
        #expect(decode("YW55IGNhcm5hbCBwbGVhc3VyZS4=") == "any carnal pleasure.")
        #expect(decode("YW55IGNhcm5h\nbCBwbGVhc3VyZS4=") == "any carnal pleasure.")
        #expect(decode("YW55IGNhcm5hbCBw\r\nbGVhc3VyZS4=\r\n") == "any carnal pleasure.")
        #expect(decode(" YW55 IGNh\tcm5hbCBwbGVhc3Vy\n") == "any carnal pleasur")
    }

    @Test func whitespaceDoesNotMakeInvalidInputValid() {
        #expect(decode("YW55IGNh-cm5hbCBwbGVhc3VyZS4=") == "")
        #expect(decode("YW55\nIGNh-cm5hbCBwbGVhc3VyZS4=") == "")
        #expect(decode(" \r\n\t") == "")
    }

    @Test(arguments: [false, true])
    func aXiphPictureIsReadAndKept(wrapped: Bool) {
        var afterRender: Int32 = -1
        #expect(xiphWrappedPictureCount(wrapped, &afterRender) == 1)
        #expect(afterRender == 1)
    }
}
