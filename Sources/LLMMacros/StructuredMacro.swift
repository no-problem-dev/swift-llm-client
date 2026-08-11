import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@Structured` macro.
///
/// On a struct it synthesizes a `jsonSchema` static property describing the stored properties,
/// and conformance to `StructuredProtocol`, `Codable` and `Sendable`.
///
/// The member expansion is what reports misuse: it throws `onlyApplicableToStruct` on any other
/// kind of declaration. The extension expansion stays silent and simply adds no conformance.
public struct StructuredMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw StructuredMacroError.onlyApplicableToStruct
        }

        let typeDescription = extractDescription(from: node)

        let properties = collectProperties(from: structDecl)

        let jsonSchemaDecl = generateJSONSchemaProperty(
            typeDescription: typeDescription,
            properties: properties
        )

        return [DeclSyntax(jsonSchemaDecl)]
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Misuse is reported by the member expansion; staying silent here avoids reporting it
        // twice.
        guard declaration.is(StructDeclSyntax.self) else {
            return []
        }

        let protocolExtension: DeclSyntax = """
            extension \(type.trimmed): StructuredProtocol, Codable, Sendable {}
            """

        guard let extensionDecl = protocolExtension.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }

    // MARK: - Private Helpers

    /// Reads the first argument of the attribute as the description of the object.
    ///
    /// Only the first segment of the string literal is read, so a description assembled by
    /// interpolation is truncated at the first `\(...)`, or dropped altogether when the
    /// interpolation comes first.
    private static func extractDescription(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
            return nil
        }
        return segment.content.text
    }

    /// Collects the stored properties the schema is built from, in declaration order.
    ///
    /// A property is dropped without a diagnostic when it carries no explicit type annotation,
    /// because the annotation is the only thing the schema type is derived from: `var count = 0`
    /// never reaches the model. Only the first binding of a declaration is read, so
    /// `var a: Int, b: Int` contributes `a` alone.
    private static func collectProperties(from structDecl: StructDeclSyntax) -> [PropertyInfo] {
        var properties: [PropertyInfo] = []

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

            let propertyName = identifier.identifier.text
            let typeName = typeAnnotation.type.trimmedDescription

            let fieldInfo = extractFieldInfo(from: varDecl.attributes)

            // Optionality is what decides whether the field is listed in "required".
            let isOptional = typeAnnotation.type.is(OptionalTypeSyntax.self)
                || typeAnnotation.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)

            let isArray = isArrayType(typeAnnotation.type)

            let baseType = extractBaseType(from: typeAnnotation.type)

            // Anything that is not a primitive is emitted as a reference to its own jsonSchema,
            // so it has to be @Structured or @StructuredEnum itself. Types such as Date, URL and
            // UUID land here too and make the expansion fail to compile.
            let isNestedType = !isPrimitiveType(baseType)

            properties.append(PropertyInfo(
                name: propertyName,
                typeName: typeName,
                baseType: baseType,
                isOptional: isOptional,
                isArray: isArray,
                isNestedType: isNestedType,
                description: fieldInfo.description,
                constraints: fieldInfo.constraints
            ))
        }

        return properties
    }

    /// Extracts the description and constraints written on `@StructuredField`.
    ///
    /// The first argument is taken as the description and everything after it as a constraint.
    /// A property with no attribute gets neither, and appears in the schema as a bare type.
    private static func extractFieldInfo(from attributes: AttributeListSyntax) -> (description: String?, constraints: [ConstraintInfo]) {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "StructuredField",
                  let arguments = attr.arguments?.as(LabeledExprListSyntax.self) else {
                continue
            }

            var description: String?
            var constraints: [ConstraintInfo] = []

            for (index, arg) in arguments.enumerated() {
                if index == 0 {
                    // The first argument is the description.
                    if let stringLiteral = arg.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                        description = segment.content.text
                    }
                } else {
                    // Everything after it is a constraint.
                    if let constraint = parseConstraint(from: arg.expression) {
                        constraints.append(constraint)
                    }
                }
            }

            return (description, constraints)
        }

        return (nil, [])
    }

    /// Parses one constraint expression, such as `.minItems(3)` or `.enum(["a", "b"])`.
    ///
    /// Only the first call argument is read, and only when it is a literal or a member access.
    /// A value reached through a constant or an expression yields nil, and the constraint
    /// disappears from the schema without a diagnostic.
    private static func parseConstraint(from expr: ExprSyntax) -> ConstraintInfo? {
        guard let funcCall = expr.as(FunctionCallExprSyntax.self),
              let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self) else {
            return nil
        }

        let constraintName = memberAccess.declName.baseName.text

        guard let firstArg = funcCall.arguments.first else {
            return nil
        }

        if let intLiteral = firstArg.expression.as(IntegerLiteralExprSyntax.self) {
            let value = intLiteral.literal.text
            return ConstraintInfo(name: constraintName, intValue: Int(value) ?? 0)
        }

        if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
           let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
            return ConstraintInfo(name: constraintName, stringValue: segment.content.text)
        }

        // An array literal, as in .enum(["a", "b"]); non-string elements are skipped.
        if let arrayExpr = firstArg.expression.as(ArrayExprSyntax.self) {
            var values: [String] = []
            for element in arrayExpr.elements {
                if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    values.append(segment.content.text)
                }
            }
            return ConstraintInfo(name: constraintName, arrayValue: values)
        }

        // A member access, as in .format(.email); the case name is carried through verbatim.
        if let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self) {
            let formatValue = memberAccess.declName.baseName.text
            return ConstraintInfo(name: constraintName, stringValue: formatValue)
        }

        return nil
    }

    /// Indicates whether the type is an array, looking through optional wrappers.
    ///
    /// An implicitly unwrapped optional is not looked through, so `[String]!` is published as a
    /// plain string rather than an array.
    private static func isArrayType(_ type: TypeSyntax) -> Bool {
        if type.is(ArrayTypeSyntax.self) {
            return true
        }
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return isArrayType(optionalType.wrappedType)
        }
        return false
    }

    /// Strips optional and array wrappers down to the type the schema is built from.
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

    /// Builds the `jsonSchema` property from the collected properties.
    ///
    /// Field names are published in snake case, `additionalProperties` is always false, and
    /// every non-optional property is listed in `required` — a Swift default value does not
    /// make a field optional to the model, so only an optional type does.
    private static func generateJSONSchemaProperty(
        typeDescription: String?,
        properties: [PropertyInfo]
    ) -> VariableDeclSyntax {
        var propertiesCode = ""
        var requiredFields: [String] = []

        for property in properties {
            let snakeCaseName = property.name.toSnakeCase()

            let schemaCode: String

            if property.isNestedType {
                // Reference the nested type's own jsonSchema instead of inlining it, so nesting
                // recurses through the type graph rather than through this macro.
                if property.isArray {
                    // An array of nested objects keeps its description and its array constraints.
                    var args = ["type: .array", "items: \(property.baseType).jsonSchema"]
                    if let desc = property.description {
                        args.insert("description: \"\(desc)\"", at: 1)
                    }
                    for constraint in property.constraints {
                        if let constraintCode = generateConstraintCode(constraint) {
                            args.append(constraintCode)
                        }
                    }
                    schemaCode = "JSONSchema(\(args.joined(separator: ", ")))"
                } else {
                    // A single nested object is referenced as it stands, which silently drops
                    // the description and any constraints written on the property.
                    schemaCode = "\(property.baseType).jsonSchema"
                }
            } else {
                var schemaArgs: [String] = []

                // An array is typed .array; its element type is carried by items below.
                if property.isArray {
                    schemaArgs.append("type: .array")
                } else {
                    let schemaType = mapToSchemaType(property.baseType)
                    schemaArgs.append("type: .\(schemaType)")
                }

                // description
                if let desc = property.description {
                    schemaArgs.append("description: \"\(desc)\"")
                }

                if property.isArray {
                    let elementType = mapToSchemaType(property.baseType)
                    schemaArgs.append("items: JSONSchema(type: .\(elementType))")
                }

                for constraint in property.constraints {
                    if let constraintCode = generateConstraintCode(constraint) {
                        schemaArgs.append(constraintCode)
                    }
                }

                schemaCode = "JSONSchema(\(schemaArgs.joined(separator: ", ")))"
            }

            propertiesCode += """
                        "\(snakeCaseName)": \(schemaCode),

            """

            // A non-optional property is required, whatever default value Swift gives it.
            if !property.isOptional {
                requiredFields.append("\"\(snakeCaseName)\"")
            }
        }

        // Drop the trailing comma so the emitted dictionary literal parses.
        if propertiesCode.hasSuffix(",\n") {
            propertiesCode = String(propertiesCode.dropLast(2)) + "\n"
        }

        let descriptionArg = typeDescription.map { "description: \"\($0)\"," } ?? ""
        let requiredArg = requiredFields.isEmpty ? "" : "required: [\(requiredFields.joined(separator: ", "))],"

        // An empty dictionary has to be spelled [:] rather than [].
        let propertiesLiteral = properties.isEmpty ? "[:]" : "[\n\(propertiesCode)        ]"

        let code: DeclSyntax = """
            public static var jsonSchema: JSONSchema {
                JSONSchema(
                    type: .object,
                    \(raw: descriptionArg)
                    properties: \(raw: propertiesLiteral),
                    \(raw: requiredArg)
                    additionalProperties: false
                )
            }
            """

        return code.cast(VariableDeclSyntax.self)
    }

    /// Maps a Swift type name onto its JSON Schema type.
    ///
    /// Only the types `isPrimitiveType` accepts ever reach it, so the object fallback stands
    /// unused: everything else is referenced through its own schema instead.
    private static func mapToSchemaType(_ swiftType: String) -> String {
        switch swiftType {
        case "String":
            return "string"
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "integer"
        case "Float", "Double", "Decimal":
            return "number"
        case "Bool":
            return "boolean"
        default:
            // Anything else is described as an object.
            return "object"
        }
    }

    /// Indicates whether the type is one the schema can describe inline.
    ///
    /// This list is the whole rule: every other type is treated as nested and referenced
    /// through its own `jsonSchema`.
    private static func isPrimitiveType(_ swiftType: String) -> Bool {
        switch swiftType {
        case "String", "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
             "Float", "Double", "Decimal", "Bool":
            return true
        default:
            return false
        }
    }

    /// Renders one constraint as an argument to the generated schema initializer.
    ///
    /// A constraint name outside the supported set, or one whose parsed value has the wrong
    /// kind, is dropped from the schema without a diagnostic.
    private static func generateConstraintCode(_ constraint: ConstraintInfo) -> String? {
        switch constraint.name {
        case "minItems", "maxItems", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "minLength", "maxLength":
            if case .int(let value) = constraint.value {
                return "\(constraint.name): \(value)"
            }
            return nil
        case "pattern", "format":
            if case .string(let value) = constraint.value {
                if constraint.name == "format" {
                    return "format: \"\(formatToJSONSchemaFormat(value))\""
                } else {
                    return "pattern: \"\(value)\""
                }
            }
            return nil
        case "enum":
            if case .array(let values) = constraint.value {
                let quoted = values.map { "\"\($0)\"" }.joined(separator: ", ")
                return "enum: [\(quoted)]"
            }
            return nil
        default:
            return nil
        }
    }

    /// Converts a format case name to the spelling JSON Schema uses.
    ///
    /// Only `dateTime` differs; every other case name is already the JSON Schema name and
    /// passes through unchanged.
    private static func formatToJSONSchemaFormat(_ format: String) -> String {
        switch format {
        case "dateTime":
            return "date-time"
        default:
            return format
        }
    }
}

// MARK: - Supporting Types

/// One stored property, reduced to what the schema generator needs to know about it.
struct PropertyInfo {
    let name: String
    let typeName: String
    let baseType: String
    let isOptional: Bool
    let isArray: Bool
    let isNestedType: Bool  // whether this is a nested StructuredProtocol type
    let description: String?
    let constraints: [ConstraintInfo]
}

/// One constraint parsed off a field attribute, paired with the value it carries.
struct ConstraintInfo {
    let name: String
    let value: ConstraintValue

    init(name: String, intValue: Int) {
        self.name = name
        self.value = .int(intValue)
    }

    init(name: String, stringValue: String) {
        self.name = name
        self.value = .string(stringValue)
    }

    init(name: String, arrayValue: [String]) {
        self.name = name
        self.value = .array(arrayValue)
    }
}

enum ConstraintValue {
    case int(Int)
    case string(String)
    case array([String])
}

// MARK: - String Extension

extension String {
    /// Converts camel case to snake case, the spelling used for schema fields and tool names.
    ///
    /// A run of capitals stays together, so `parseHTTPResponse` becomes `parse_http_response`.
    /// Digits are not treated as word boundaries.
    func toSnakeCase() -> String {
        var result = ""
        for (index, character) in self.enumerated() {
            if character.isUppercase {
                if index > 0 {
                    // Break only at a word boundary: after a lowercase letter, or before the
                    // last capital of a run.
                    let prevIndex = self.index(self.startIndex, offsetBy: index - 1)
                    let prevChar = self[prevIndex]
                    if prevChar.isLowercase {
                        result += "_"
                    } else if index + 1 < self.count {
                        let nextIndex = self.index(self.startIndex, offsetBy: index + 1)
                        let nextChar = self[nextIndex]
                        if nextChar.isLowercase {
                            result += "_"
                        }
                    }
                }
                result += character.lowercased()
            } else {
                result += String(character)
            }
        }
        return result
    }
}

// MARK: - Errors

enum StructuredMacroError: Error, CustomStringConvertible {
    case onlyApplicableToStruct

    var description: String {
        switch self {
        case .onlyApplicableToStruct:
            return "@Structured can only be applied to structs"
        }
    }
}
