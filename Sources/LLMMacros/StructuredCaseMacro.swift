import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@StructuredCase` marker macro.
///
/// It synthesizes nothing of its own. `@StructuredEnum` reads the attribute to attach a
/// description to a case, and that description reaches the model through `enumDescription`
/// rather than through the schema — the generated JSON Schema lists the raw values alone. A
/// description written on a case declaration that names several cases applies to all of them.
///
/// Attached to anything other than an enum case, it throws `onlyApplicableToEnumCase`.
///
/// ## Example
///
/// ```swift
/// @StructuredEnum("Priority")
/// enum Priority: String {
///     @StructuredCase("Not urgent")
///     case low
///
///     @StructuredCase("Ordinary work")
///     case medium
///
///     @StructuredCase("Urgent")
///     case high
/// }
/// ```
public struct StructuredCaseMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(EnumCaseDeclSyntax.self) else {
            throw StructuredCaseMacroError.onlyApplicableToEnumCase
        }

        // Nothing to emit: the description is read by @StructuredEnum.
        return []
    }
}

// MARK: - Errors

enum StructuredCaseMacroError: Error, CustomStringConvertible {
    case onlyApplicableToEnumCase

    var description: String {
        switch self {
        case .onlyApplicableToEnumCase:
            return "@StructuredCase can only be applied to enum cases"
        }
    }
}
