import Foundation
import FuzzyMatch
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class FuzzyTests: TestCaseModel {
    @available(macOS 26, iOS 26, *)
    @Test func search() async throws {
        let benchmark = Benchmark(label: "\((#file as NSString).lastPathComponent):\(#function)"); defer { benchmark.stop() }
        //

        struct Object: Searchable {
            var searchableValue: String { "bird fish frog bear" }
            var searchableArray: [String] { ["bird", "fish", "frog", "bear"] }
        }

        let obj = Object()

        #expect(obj.fuzzyMatch(to: ["bird"]) == 1)
    }
}
