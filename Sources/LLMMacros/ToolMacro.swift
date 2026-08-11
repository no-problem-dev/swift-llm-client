import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@Tool` macro.
///
/// On a struct it synthesizes `toolName` and `toolDescription`, a nested `Arguments` type built
/// from the `@ToolArgument` properties, the `inputSchema` derived from it, an `arguments`
/// property, the initializers a tool is registered with, `execute(with:)`, and conformance to
/// `Tool` and `Sendable`.
///
/// The member expansion is what reports misuse: it throws `onlyApplicableToStruct` on any other
/// kind of declaration. The extension expansion stays silent and simply adds no conformance.
public struct ToolMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw ToolMacroError.onlyApplicableToStruct
        }

        let typeName = structDecl.name.text

        // What the model reads when deciding whether to call the tool.
        let toolDescription = extractDescription(from: node)
            ?? "Tool: \(typeName)"

        // The name the model calls the tool by, defaulting to the type name in snake case.
        let toolName = extractToolName(from: node)
            ?? typeName.toSnakeCase()

        // Three groups of stored properties, and only the first is ever shown to the model:
        // arguments it fills in, configuration the caller injects, and everything else, which
        // the expansion leaves alone.
        let arguments = collectToolArguments(from: structDecl)

        let injected = collectInjectedProperties(from: structDecl)

        var members: [DeclSyntax] = []

        members.append("""
            public let toolName: String = "\(raw: toolName)"
            """)

        members.append("""
            public let toolDescription: String = "\(raw: toolDescription)"
            """)

        let argumentsDecl = generateArgumentsType(arguments: arguments)
        members.append(argumentsDecl)

        members.append("""
            public var inputSchema: JSONSchema {
                Arguments.jsonSchema
            }
            """)

        // Mutable so that execute(with:) can swap in the values of a single call.
        members.append("""
            public var arguments: Arguments
            """)

        let initDecl = generateInitializer(arguments: arguments, injected: injected)
        members.append(initDecl)

        let executeDecl = generateExecuteMethod(typeName: typeName, arguments: arguments)
        members.append(executeDecl)

        return members
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            return []
        }

        let protocolExtension: DeclSyntax = """
            extension \(type.trimmed): Tool, Sendable {}
            """

        guard let extensionDecl = protocolExtension.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }

    // MARK: - Private Helpers

    /// Reads the unlabelled first argument of the attribute as the tool description.
    ///
    /// Only the first segment of the string literal is read, so a description assembled by
    /// interpolation is truncated at the first `\(...)`, or dropped altogether when the
    /// interpolation comes first — and the caller then falls back to `Tool: TypeName`, which
    /// tells the model nothing about when to call it.
    private static func extractDescription(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              firstArg.label == nil,  // unlabelled argument
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }

    /// Reads the `name:` argument of the attribute, the name the model calls the tool by.
    ///
    /// Only a plain string literal is recognised, and the caller otherwise falls back to the
    /// snake-cased type name.
    private static func extractToolName(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        for arg in arguments {
            if arg.label?.text == "name",
               let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                return segment.content.text
            }
        }
        return nil
    }

    /// Collects the properties marked `@ToolArgument`, the only ones the model ever sees.
    ///
    /// This is one half of the rule that decides what a property becomes. A property marked
    /// `@ToolArgument` turns into a field of `Arguments` and appears in the input schema; a
    /// plain stored property becomes injected configuration the model is never told about; a
    /// computed property, one with a default value, or one marked `@ToolExclude` becomes
    /// neither.
    ///
    /// A property without an explicit type annotation is dropped without a diagnostic, since
    /// the annotation is the only thing the schema type is derived from. Only the first binding
    /// of a declaration is read, so `var a: Int, b: Int` contributes `a` alone.
    private static func collectToolArguments(from structDecl: StructDeclSyntax) -> [ToolArgumentInfo] {
        var arguments: [ToolArgumentInfo] = []

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else {
                continue
            }

            // A computed property has no storage to decode a model response into.
            if binding.accessorBlock != nil {
                continue
            }

            let argInfo = extractToolArgumentInfo(from: varDecl.attributes)

            guard argInfo.hasAttribute else {
                continue
            }

            let propertyName = identifier.identifier.text
            let typeName = typeAnnotation.type.trimmedDescription
            let isOptional = typeAnnotation.type.is(OptionalTypeSyntax.self)
                || typeAnnotation.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
            let isArray = isArrayType(typeAnnotation.type)
            let baseType = extractBaseType(from: typeAnnotation.type)

            arguments.append(ToolArgumentInfo(
                name: propertyName,
                typeName: typeName,
                baseType: baseType,
                isOptional: isOptional,
                isArray: isArray,
                description: argInfo.description,
                constraintSource: argInfo.constraintSource
            ))
        }

        return arguments
    }

    /// Collects the properties the caller supplies when registering the tool.
    ///
    /// This is the other half of the classification rule. A stored property becomes injected
    /// configuration only when it carries no attribute, no default value and no accessor; it
    /// then turns into a parameter of the generated initializer and stays out of the input
    /// schema, which is where an API key, a client, or fetched state belongs. A default value,
    /// an accessor, `@ToolArgument`, or `@ToolExclude` each take it out of this set, and a
    /// property without an explicit type annotation is dropped without a diagnostic.
    private static func collectInjectedProperties(from structDecl: StructDeclSyntax) -> [InjectedPropertyInfo] {
        var injected: [InjectedPropertyInfo] = []

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else {
                continue
            }

            // A computed property needs nothing injected into it.
            if binding.accessorBlock != nil {
                continue
            }

            // A property that already carries a value must not become a required parameter.
            if binding.initializer != nil {
                continue
            }

            // Arguments come from the model, not from the caller, and are handled separately.
            let argInfo = extractToolArgumentInfo(from: varDecl.attributes)
            if argInfo.hasAttribute {
                continue
            }

            // Opted out explicitly; the generated initializer neither takes nor assigns it.
            if hasToolExcludeAttribute(varDecl.attributes) {
                continue
            }

            let propertyName = identifier.identifier.text
            let typeName = typeAnnotation.type.trimmedDescription
            let isLet = varDecl.bindingSpecifier.tokenKind == .keyword(.let)

            injected.append(InjectedPropertyInfo(
                name: propertyName,
                typeName: typeName,
                isLet: isLet
            ))
        }

        return injected
    }

    /// Indicates whether a property carries `@ToolExclude`.
    ///
    /// The attribute name is matched as written, so a module-qualified or aliased spelling goes
    /// unrecognised and the property is treated as injected configuration instead.
    private static func hasToolExcludeAttribute(_ attributes: AttributeListSyntax) -> Bool {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "ToolExclude" else {
                continue
            }
            return true
        }
        return false
    }

    /// Extracts the description and constraints written on `@ToolArgument`.
    ///
    /// The first argument is taken as the description and everything after it as a constraint.
    /// Constraints are kept as source text rather than parsed here: `generateArgumentsType` writes
    /// them straight back onto the generated `@StructuredField`, so a constraint on a tool argument
    /// reaches the schema by exactly the same path as one written on a structured field.
    private static func extractToolArgumentInfo(
        from attributes: AttributeListSyntax
    ) -> (hasAttribute: Bool, description: String?, constraintSource: [String]) {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "ToolArgument",
                  let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
                continue
            }

            var description: String?
            var constraintSource: [String] = []

            for (index, arg) in arguments.enumerated() {
                if index == 0 {
                    // The first argument is the description.
                    if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        description = segment.content.text
                    }
                } else {
                    // Everything after it is a constraint, carried through as written.
                    constraintSource.append(arg.expression.trimmedDescription)
                }
            }

            return (true, description, constraintSource)
        }

        return (false, nil, [])
    }

    /// Indicates whether the type is an array, looking through optional wrappers.
    ///
    /// The answer only decides which placeholder value the property is seeded with, since the
    /// schema itself is built by `@Structured` from the generated `Arguments` type.
    private static func isArrayType(_ type: TypeSyntax) -> Bool {
        if type.is(ArrayTypeSyntax.self) {
            return true
        }
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return isArrayType(optionalType.wrappedType)
        }
        return false
    }

    /// Strips optional and array wrappers down to the element type.
    private static func extractBaseType(from type: TypeSyntax) -> String {
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return extractBaseType(from: optionalType.wrappedType)
        }
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            return extractBaseType(from: arrayType.element)
        }
        if let implicitOptional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return extractBaseType(from: implicitOptional.wrappedType)
        }
        return type.trimmedDescription
    }

    /// Builds the nested `Arguments` type, from which `@Structured` derives the input schema.
    ///
    /// Every field is emitted with a default value so the generated `init()` can stand the type
    /// up before the model has said anything; the fields stay non-optional, so the schema still
    /// lists them as required. The description and every constraint reach `@StructuredField`
    /// unchanged, and a property with no description falls back to its own name, which is what the
    /// model then reads.
    private static func generateArgumentsType(arguments: [ToolArgumentInfo]) -> DeclSyntax {
        if arguments.isEmpty {
            // Alias the shared empty type rather than emitting an empty struct.
            return """
                public typealias Arguments = EmptyArguments
                """
        }

        var propertiesCode = ""
        for arg in arguments {
            let defaultValue = defaultValueForType(arg.typeName, isOptional: arg.isOptional, isArray: arg.isArray)
            let constraints = arg.constraintSource.map { ", \($0)" }.joined()
            propertiesCode += "    @StructuredField(\"\(arg.description ?? arg.name)\"\(constraints))\n"
            propertiesCode += "    public var \(arg.name): \(arg.typeName) = \(defaultValue)\n"
        }

        return """
            @Structured
            public struct Arguments {
            \(raw: propertiesCode)}
            """
    }

    /// Builds the initializers a tool is registered and re-created with.
    ///
    /// The injected properties always come first, so a tool joins a tool set as
    /// `MyTool(injectedProp: value)` with its argument values still unset. A second initializer
    /// takes the arguments as well, which is how `execute(with:)` rebuilds the tool for a single
    /// call. A tool with no `@ToolArgument` property gets one initializer instead of two, its
    /// `arguments` parameter defaulting to `EmptyArguments()`.
    private static func generateInitializer(
        arguments: [ToolArgumentInfo],
        injected: [InjectedPropertyInfo]
    ) -> DeclSyntax {
        // Parameter list for the injected properties, for example "sessions: [SessionRecord]".
        let injectedParams = injected.map { "\($0.name): \($0.typeName)" }.joined(separator: ", ")
        let injectedAssignments = injected.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n    ")

        if arguments.isEmpty {
            if injected.isEmpty {
                return """
                    public init(arguments: Arguments = EmptyArguments()) {
                        self.arguments = arguments
                    }
                    """
            } else {
                return """
                    public init(\(raw: injectedParams), arguments: Arguments = EmptyArguments()) {
                        \(raw: injectedAssignments)
                        self.arguments = arguments
                    }
                    """
            }
        }

        // The @ToolArgument properties live on the tool itself as well as inside Arguments, so
        // they have to be seeded before any call arrives.
        var defaultValues: [String] = []
        for arg in arguments {
            let defaultValue = defaultValueForType(arg.typeName, isOptional: arg.isOptional, isArray: arg.isArray)
            defaultValues.append("self.\(arg.name) = \(defaultValue)")
        }
        let defaultAssignments = defaultValues.joined(separator: "\n    ")

        // Mirror each decoded argument onto its own property, so call() can read either.
        var argAssignments = ""
        for arg in arguments {
            argAssignments += "    self.\(arg.name) = arguments.\(arg.name)\n"
        }

        if injected.isEmpty {
            // Nothing to inject, so registration needs no parameters at all.
            return """
                public init() {
                    // ToolSet 登録時のデフォルト初期化
                    // 実際の引数は execute(with:) で設定される
                    \(raw: defaultAssignments)
                    // arguments は execute 時に設定されるため、空の Arguments で初期化
                    self.arguments = Arguments()
                }

                public init(arguments: Arguments) {
                    self.arguments = arguments
                \(raw: argAssignments)}
                """
        } else {
            // Registration has to supply the injected properties, so they become parameters.
            return """
                public init(\(raw: injectedParams)) {
                    // ToolSet 登録時の初期化（注入プロパティを受け取る）
                    // LLM 引数は execute(with:) で設定される
                    \(raw: injectedAssignments)
                    \(raw: defaultAssignments)
                    self.arguments = Arguments()
                }

                public init(\(raw: injectedParams), arguments: Arguments) {
                    \(raw: injectedAssignments)
                    self.arguments = arguments
                \(raw: argAssignments)}
                """
        }
    }

    /// Returns the placeholder a generated property is seeded with before any call arrives.
    ///
    /// A type outside the primitive set falls back to `Type()`, so a custom argument type has to
    /// offer a no-argument initializer or the expansion will not compile.
    private static func defaultValueForType(_ typeName: String, isOptional: Bool, isArray: Bool) -> String {
        if isOptional {
            return "nil"
        }
        if isArray {
            return "[]"
        }
        let baseType = typeName.replacing("?", with: "")
        switch baseType {
        case "String":
            return "\"\""
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "0"
        case "Double", "Float", "CGFloat":
            return "0.0"
        case "Bool":
            return "false"
        default:
            // Assume a custom type can be default-initialized.
            return "\(baseType)()"
        }
    }

    /// Builds `execute(with:)`, the entry point that raw tool-call JSON is handed to.
    ///
    /// The generated body decodes with `.convertFromSnakeCase`, which is what turns the
    /// `sort_by` the model emits back into `sortBy`, then applies the values to a copy of the
    /// registered tool and calls `call()` on the copy. The registered instance is never mutated,
    /// so overlapping calls cannot see each other's arguments while the injected configuration
    /// stays readable inside `call()`.
    private static func generateExecuteMethod(typeName: String, arguments: [ToolArgumentInfo]) -> DeclSyntax {
        var copyAssignments = ""
        for arg in arguments {
            copyAssignments += "    copy.\(arg.name) = args.\(arg.name)\n"
        }

        if arguments.isEmpty {
            // No arguments to decode, so whatever payload arrives is ignored.
            return """
                public func execute(with argumentsData: Data) async throws -> ToolResult {
                    let result = try await self.call()
                    return try result.asToolResult()
                }
                """
        }

        return """
            public func execute(with argumentsData: Data) async throws -> ToolResult {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let args = try decoder.decode(Arguments.self, from: argumentsData)
                var copy = self
                copy.arguments = args
            \(raw: copyAssignments)    let result = try await copy.call()
                return try result.asToolResult()
            }
            """
    }
}

// MARK: - ToolArgumentInfo

/// One property published to the model as an argument it fills in.
struct ToolArgumentInfo {
    let name: String
    let typeName: String
    let baseType: String
    let isOptional: Bool
    let isArray: Bool
    let description: String?

    /// The source text of each constraint written on `@ToolArgument`, re-emitted verbatim onto the
    /// generated `@StructuredField` so `@Structured` parses it exactly as if it had been written
    /// there by hand.
    let constraintSource: [String]
}

// MARK: - InjectedPropertyInfo

/// One stored property supplied by the caller at registration rather than by the model.
struct InjectedPropertyInfo {
    let name: String
    let typeName: String
    let isLet: Bool
}

// MARK: - ToolMacroError

enum ToolMacroError: Error, CustomStringConvertible {
    case onlyApplicableToStruct

    var description: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@Tool can only be applied to structs"
        }
    }
}
