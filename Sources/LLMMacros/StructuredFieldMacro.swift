import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@StructuredField` marker macro.
///
/// It synthesizes nothing of its own. The description and constraints written on the attribute
/// are read by `@Structured` while it walks the stored properties and builds `jsonSchema`.
///
/// Attached to anything other than a variable declaration, it throws
/// `onlyApplicableToProperty`.
public struct StructuredFieldMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(VariableDeclSyntax.self) else {
            throw StructuredFieldMacroError.onlyApplicableToProperty
        }

        // Nothing to emit: the metadata is read by @Structured.
        return []
    }
}

// MARK: - Errors

enum StructuredFieldMacroError: Error, CustomStringConvertible {
    case onlyApplicableToProperty

    var description: String {
        switch self {
        case .onlyApplicableToProperty:
            return "@StructuredField can only be applied to properties"
        }
    }
}
