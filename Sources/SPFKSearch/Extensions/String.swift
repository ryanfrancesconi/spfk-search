// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

extension String {
    /// Normalizes a string by removing case and diacritics for "loose" matching.
    public var normalized: String {
        folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}
