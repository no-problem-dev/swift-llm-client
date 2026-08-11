import SwiftSyntax
import SwiftSyntaxMacros

/// Implements the `@StructuredEnum` macro.
///
/// On an enum with a `String` raw value it synthesizes a `jsonSchema` static property holding a
/// string schema whose `enum` lists the raw values, an `enumDescription` static property that
/// spells the cases out for a prompt, and conformance to `StructuredProtocol` and `Sendable`.
///
/// The member expansion is what reports misuse: it throws `onlyApplicableToEnum` on any other
/// kind of declaration, `requiresStringRawValue` when `String` is absent from the inheritance
/// clause, and `requiresAtLeastOneCase` on an empty enum. The extension expansion stays silent
/// in those cases and simply adds no conformance.
///
/// ## Example
///
/// ```swift
/// @StructuredEnum("Status")
/// enum Status: String {
///     case active
///     case inactive
///     case pending
/// }
/// ```
///
/// The schema it generates:
/// ```json
/// {
///     "type": "string",
///     "description": "Status",
///     "enum": ["active", "inactive", "pending"]
/// }
/// ```
public struct StructuredEnumMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw StructuredEnumMacroError.onlyApplicableToEnum
        }

        guard hasStringRawValue(enumDecl) else {
            throw StructuredEnumMacroError.requiresStringRawValue
        }

        let typeDescription = extractDescription(from: node)

        let cases = collectEnumCases(from: enumDecl)

        guard !cases.isEmpty else {
            throw StructuredEnumMacroError.requiresAtLeastOneCase
        }

        let jsonSchemaDecl = generateJSONSchemaProperty(
            typeDescription: typeDescription,
            cases: cases
        )

        let enumDescriptionDecl = generateEnumDescriptionProperty(
            typeDescription: typeDescription,
            cases: cases
        )

        return [DeclSyntax(jsonSchemaDecl), DeclSyntax(enumDescriptionDecl)]
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
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            return []
        }

        guard hasStringRawValue(enumDecl) else {
            return []
        }

        let protocolExtension: DeclSyntax = """
            extension \(type.trimmed): StructuredProtocol, Sendable {}
            """

        guard let extensionDecl = protocolExtension.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [extensionDecl]
    }

    // MARK: - Private Helpers

    /// Reads the first argument of the attribute as the description of the enum.
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

    /// Indicates whether `String` appears in the enum's inheritance clause.
    ///
    /// The match is textual, so an enum that reaches `String` raw values through a type alias
    /// is rejected.
    private static func hasStringRawValue(_ enumDecl: EnumDeclSyntax) -> Bool {
        guard let inheritanceClause = enumDecl.inheritanceClause else {
            return false
        }

        for inheritedType in inheritanceClause.inheritedTypes {
            let typeName = inheritedType.type.trimmedDescription
            if typeName == "String" {
                return true
            }
        }

        return false
    }

    /// Collects the cases in declaration order, which is the order the schema lists them in.
    ///
    /// A `@StructuredCase` description is read once per case declaration and applied to every
    /// element it names, so `case low, medium` gives both the same description.
    private static func collectEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCaseInfo] {
        var cases: [EnumCaseInfo] = []

        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                continue
            }

            let caseDescription = extractCaseDescription(from: caseDecl.attributes)

            for element in caseDecl.elements {
                let name = element.name.text

                // Falling back to the case name matches the raw value Swift synthesizes.
                let rawValue: String
                if let rawValueClause = element.rawValue,
                   let stringLiteral = rawValueClause.value.as(StringLiteralExprSyntax.self),
                   let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                    rawValue = segment.content.text
                } else {
                    rawValue = name
                }

                cases.append(EnumCaseInfo(name: name, rawValue: rawValue, description: caseDescription))
            }
        }

        return cases
    }

    /// Reads the description written on `@StructuredCase`, taking the first one that carries it.
    ///
    /// Only a plain string literal is recognised, so an interpolated description leaves the
    /// case undescribed.
    private static func extractCaseDescription(from attributes: AttributeListSyntax) -> String? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                  let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                  identifier.name.text == "StructuredCase",
                  let arguments = attr.arguments?.as(LabeledExprListSyntax.self),
                  let firstArg = arguments.first,
                  let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
                  let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
                continue
            }
            return segment.content.text
        }
        return nil
    }

    /// Builds the `jsonSchema` property: a string schema whose `enum` lists the raw values.
    ///
    /// Per-case descriptions are deliberately left out; they travel through `enumDescription`.
    private static func generateJSONSchemaProperty(
        typeDescription: String?,
        cases: [EnumCaseInfo]
    ) -> VariableDeclSyntax {
        let enumValues = cases.map { "\"\($0.rawValue)\"" }.joined(separator: ", ")
        let descriptionArg = typeDescription.map { "description: \"\($0)\", " } ?? ""

        let code: DeclSyntax = """
            public static var jsonSchema: JSONSchema {
                JSONSchema(
                    type: .string,
                    \(raw: descriptionArg)enum: [\(raw: enumValues)]
                )
            }
            """

        return code.cast(VariableDeclSyntax.self)
    }

    /// Builds the `enumDescription` property, the wording to hand to the model in a prompt.
    ///
    /// The schema carries only the raw values, so a per-case description reaches the model
    /// through this string or not at all. The lines are joined with escaped newlines, which
    /// keeps the emitted literal on a single line.
    ///
    /// ```
    /// Task priority:
    /// - low: not urgent
    /// - medium: ordinary work
    /// - high: urgent
    /// ```
    private static func generateEnumDescriptionProperty(
        typeDescription: String?,
        cases: [EnumCaseInfo]
    ) -> VariableDeclSyntax {
        var lines: [String] = []

        // Title line, present only when the enum itself was described.
        if let desc = typeDescription {
            lines.append("\(desc):")
        }

        for caseInfo in cases {
            if let caseDesc = caseInfo.description {
                lines.append("- \(caseInfo.rawValue): \(caseDesc)")
            } else {
                lines.append("- \(caseInfo.rawValue)")
            }
        }

        let description = lines.joined(separator: "\\n")

        let code: DeclSyntax = """
            public static var enumDescription: String {
                \"\(raw: description)\"
            }
            """

        return code.cast(VariableDeclSyntax.self)
    }
}

// MARK: - Supporting Types

/// One case of a `@StructuredEnum`, as the schema and the prompt text need to see it.
struct EnumCaseInfo {
    let name: String
    let rawValue: String
    let description: String?
}

// MARK: - Errors

enum StructuredEnumMacroError: Error, CustomStringConvertible {
    case onlyApplicableToEnum
    case requiresStringRawValue
    case requiresAtLeastOneCase

    var description: String {
        switch self {
        case .onlyApplicableToEnum:
            return "@StructuredEnum can only be applied to enums"
        case .requiresStringRawValue:
            return "@StructuredEnum requires enum with String raw value"
        case .requiresAtLeastOneCase:
            return "@StructuredEnum requires at least one case"
        }
    }
}
