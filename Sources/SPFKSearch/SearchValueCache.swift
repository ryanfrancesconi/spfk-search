// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation
import os

/// A ``SearchableValue`` built when first read and kept, for an element whose value is costly to
/// build and which most reads never search.
///
/// A reference, so every copy of the element holding it shares one build. The holder replaces it
/// with a new cache whenever a field the value reads from changes, which is what keeps copies
/// independent.
public final class SearchValueCache: Sendable {
    private let state = OSAllocatedUnfairLock<SearchableValue?>(initialState: nil)

    public init() {}

    /// The kept value, or `build`'s once. Built outside the lock, so two first reads racing may
    /// both build; the first to finish is kept.
    public func value(_ build: () -> SearchableValue) -> SearchableValue {
        if let kept = state.withLock({ $0 }) { return kept }

        let built = build()

        return state.withLock { kept in
            if let kept { return kept }
            kept = built
            return built
        }
    }
}
