// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import TagLibTestHelper
import Testing

/// An INFO field with no property key is reported in `unsupportedData()` by its ID, so passing that
/// list to `removeUnsupportedProperties()`, which erases by ID, removes it.
@Suite
struct RIFFInfoUnsupportedTests {
    private func firstUnsupported(_ result: InfoUnsupportedResult) -> String {
        withUnsafeBytes(of: result.firstUnsupported) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    @Test func unmappedFieldIsReportedByID() {
        let result = infoUnsupportedProperties("Title", "ITRK")

        #expect(result.unsupportedCount == 1)
        #expect(firstUnsupported(result) == "ITRK")
        #expect(result.titleMapped)
    }

    @Test func removeUnsupportedPropertiesRemovesUnmappedField() {
        let result = infoUnsupportedProperties("Title", "ITRK")

        #expect(!result.fieldRemains)
        #expect(result.titleKept)
    }
}
