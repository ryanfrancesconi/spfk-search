// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-search

import Foundation

/// One field compared against one operand.
public struct SearchRule: Sendable, Hashable {
    /// Persisted. Unknown to the evaluating product means the rule matches nothing.
    public var fieldID: String
    public var op: SearchOperator
    public var operand: SearchOperand

    public init(fieldID: String, op: SearchOperator, operand: SearchOperand = .none) {
        self.fieldID = fieldID
        self.op = op
        self.operand = operand
    }
}
