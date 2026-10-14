// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import FuzzyMatch
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKSearch

final class MultiTermQueryTests: TestCaseModel {
    private struct File: Searchable {
        let name: String
        var searchableValue: SearchableValue { [name] }
    }

    private let files: [File] = [
        "Airport_Runway_OCP-1457-007",
        "Airport_Runway_Boeing_747_Fly_By_OCP-1457-008",
        "Jets_Taxi_and_Idle_CU_Airport_Runway_OCP-1343-054",
        "Airport_PA_OCP-1222-026-10",
        "LAX_Airport_Terminal_OCM-0021-020",
        "Jet_Plane_Runway_Taxi_OCP-1999-001",
        "Door_High_Tech_Electric_Sliding_Glass_Door_OCP-0125-05",
    ].map(File.init)

    private func matches(_ query: String) -> Set<String> {
        let query = DelimitedQuery(string: query)
        let gated = files.filter { $0.hasNearMatch(query: query) }
        let scored = QuerySearch.batchScore(gated, query: query, matchConfig: QuerySearch.defaultConfig)
        return Set(scored.map(\.element.name))
    }

    @Test func addingATermNarrowsTheResults() {
        let airport = matches("airport")
        let airportRunway = matches("airport runway")

        #expect(airportRunway.isSubset(of: airport))
        #expect(airportRunway.count < airport.count)
    }

    @Test func everyTermMustMatch() {
        let airportRunway = matches("airport runway")

        #expect(airportRunway == [
            "Airport_Runway_OCP-1457-007",
            "Airport_Runway_Boeing_747_Fly_By_OCP-1457-008",
            "Jets_Taxi_and_Idle_CU_Airport_Runway_OCP-1343-054",
        ])
    }

    @Test func commasMatchAnyPart() {
        #expect(matches("terminal, runway") == [
            "Airport_Runway_OCP-1457-007",
            "Airport_Runway_Boeing_747_Fly_By_OCP-1457-008",
            "Jets_Taxi_and_Idle_CU_Airport_Runway_OCP-1343-054",
            "LAX_Airport_Terminal_OCM-0021-020",
            "Jet_Plane_Runway_Taxi_OCP-1999-001",
        ])
    }

    @Test func aPluralWordMatchesThroughItsSingular() {
        #expect(matches("airport runways") == matches("airport runway"))
    }

    @Test func similarityRequiresEveryWord() {
        let query = DelimitedQuery(string: "airport runway")

        #expect(File(name: "Airport_PA_OCP-1222-026-10").similarity(to: query) == 0)
        #expect(File(name: "Airport_Runway_OCP-1457-007").similarity(to: query) ?? 0 > 0)
    }

    @Test func synonymsStandInForTheirOwnWord() {
        let query = DelimitedQuery(string: "airport runway").expanded { group in
            group.contains("runway") ? ["terminal"] : []
        }

        #expect(query.termGroups == [["airport"], ["runway", "terminal"]])
        #expect(query.array.contains("terminal"))
    }
}
