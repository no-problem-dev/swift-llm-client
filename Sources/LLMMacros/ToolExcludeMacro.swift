import SwiftSyntax
import SwiftSyntaxMacros

/// `@ToolExclude` マクロの実装
///
/// `@Tool` マクロが適用された構造体のストアドプロパティに付けることで、
/// そのプロパティを注入プロパティから除外する。
///
/// コールバッククロージャなど、ツールの引数でも注入プロパティでもない
/// プロパティを `@Tool` マクロの処理対象外にするために使用する。
public struct ToolExcludeMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // マーカーとして機能
        // 実際の処理は @Tool マクロ側で行う
        return []
    }
}
