import SwiftSyntax
import SwiftSyntaxMacros

/// `@ToolArgument` マクロの実装
///
/// `@Tool` マクロがプロパティを `Arguments` 型に含めるための
/// マーカーとして機能する。
///
/// 実際のコード生成は `@Tool` マクロ側で行われる。
public struct ToolArgumentMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // このマクロはマーカーとして機能
        // 実際の処理は @Tool マクロ側で行う
        return []
    }
}
