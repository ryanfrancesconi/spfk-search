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
