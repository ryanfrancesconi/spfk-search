import Foundation
import FuzzyFind
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class LevenshteinTests: TestCaseModel {
    @Test func similarity() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)")
        defer { benchmark.stop() }

        let object = LevenshteinDistance(
            string: "A string is a séries of characters, such as swift"
        )

        let score = object.similarity(to: "string")

        Log.debug(score)
    }
}
