// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

public enum SearchMethod: Sendable, Hashable, Equatable {
    @available(macOS 26, iOS 26, *)
    case fuzzy

    @available(macOS 14, iOS 17, *)
    case exact

    @available(macOS 14, iOS 17, *)
    case best
}
