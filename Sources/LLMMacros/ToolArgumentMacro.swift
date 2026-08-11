import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@ToolArgument` marker macro.
///
/// It synthesizes nothing of its own. `@Tool` reads the attribute off each stored property to
/// decide which ones become fields of the generated `Arguments` type, and those are the only
/// properties published to the model in the input schema.
///
/// The declaration it is attached to is never checked here, so the attribute written anywhere
/// other than a stored property of a `@Tool` struct is ignored without a diagnostic.
public struct ToolArgumentMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Nothing to emit: the attribute is read by @Tool.
        return []
    }
}
