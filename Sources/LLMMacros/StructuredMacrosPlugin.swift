import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct LLMMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StructuredMacro.self,
        StructuredFieldMacro.self,
        StructuredEnumMacro.self,
        StructuredCaseMacro.self,
        ToolMacro.self,
        ToolArgumentMacro.self,
    ]
}
