import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@ToolExclude` marker macro.
///
/// It synthesizes nothing of its own. `@Tool` reads the attribute to keep a stored property out
/// of the injected configuration, so the generated initializer neither takes it as a parameter
/// nor assigns it. That is what a callback closure needs: a member that is neither an argument
/// the model fills in nor something the caller should have to supply at registration. Since
/// nothing initializes such a property, it has to be optional or carry a default value.
///
/// The declaration it is attached to is never checked here, so a misplaced attribute is ignored
/// without a diagnostic.
public struct ToolExcludeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Nothing to emit: the attribute is read by @Tool.
        return []
    }
}
