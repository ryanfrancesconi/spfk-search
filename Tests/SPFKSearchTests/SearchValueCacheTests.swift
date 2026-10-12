// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import Testing

@testable import SPFKSearch

struct SearchValueCacheTests {
    @Test func buildsOnFirstReadOnly() {
        let cache = SearchValueCache()
        var builds = 0

        let first = cache.value { builds += 1; return ["zebra"] }
        let second = cache.value { builds += 1; return ["okapi"] }

        #expect(first == ["zebra"])
        #expect(second == ["zebra"])
        #expect(builds == 1)
    }
}
