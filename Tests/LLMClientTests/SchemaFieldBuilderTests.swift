import Testing
@testable import LLMClient

@Suite("SchemaFieldBuilder Tests")
struct SchemaFieldBuilderTests {

    @Test func basicFields() {
        @SchemaFieldBuilder
        func build() -> [NamedSchema] {
            JSONSchema.string(description: "名前").named("name")
            JSONSchema.integer(description: "年齢").named("age")
        }

        let fields = build()
        #expect(fields.count == 2)
        #expect(fields[0].name == "name")
        #expect(fields[0].isRequired == true)
        #expect(fields[1].name == "age")
    }

    @Test func optionalField() {
        @SchemaFieldBuilder
        func build() -> [NamedSchema] {
            JSONSchema.string().named("required_field")
            JSONSchema.string().named("optional_field").optional()
        }

        let fields = build()
        #expect(fields[0].isRequired == true)
        #expect(fields[1].isRequired == false)
    }

    @Test func conditionalField() {
        let includeEmail = true

        @SchemaFieldBuilder
        func build() -> [NamedSchema] {
            JSONSchema.string().named("name")
            if includeEmail {
                JSONSchema.string(format: "email").named("email")
            }
        }

        let fields = build()
        #expect(fields.count == 2)
        #expect(fields[1].name == "email")
    }

    @Test func conditionalFieldFalse() {
        let includeEmail = false

        @SchemaFieldBuilder
        func build() -> [NamedSchema] {
            JSONSchema.string().named("name")
            if includeEmail {
                JSONSchema.string(format: "email").named("email")
            }
        }

        let fields = build()
        #expect(fields.count == 1)
    }

    @Test func ifElseBranch() {
        let useMetric = true

        @SchemaFieldBuilder
        func build() -> [NamedSchema] {
            if useMetric {
                JSONSchema.string().named("celsius")
            } else {
                JSONSchema.string().named("fahrenheit")
            }
        }

        let fields = build()
        #expect(fields.count == 1)
        #expect(fields[0].name == "celsius")
    }

    @Test func forLoop() {
        let tags = ["a", "b", "c"]

        @SchemaFieldBuilder
        func build() -> [NamedSchema] {
            for tag in tags {
                JSONSchema.string(description: tag).named(tag)
            }
        }

        let fields = build()
        #expect(fields.count == 3)
        #expect(fields.map(\.name) == ["a", "b", "c"])
    }

    @Test func objectFromFields() {
        let fields = [
            JSONSchema.string().named("name"),
            JSONSchema.integer().named("age").optional(),
        ]

        let schema = JSONSchema.object(description: "User", fields: fields)
        #expect(schema.type == .object)
        #expect(schema.description == "User")
        #expect(schema.properties?["name"] != nil)
        #expect(schema.properties?["age"] != nil)
        #expect(schema.required == ["name"])
    }

    @Test func namedExtension() {
        let field = JSONSchema.boolean(description: "アクティブ").named("active")
        #expect(field.name == "active")
        #expect(field.isRequired == true)
        #expect(field.schema.type == .boolean)
    }

    @Test func requiredModifier() {
        let field = JSONSchema.string().named("field").optional().required()
        #expect(field.isRequired == true)
    }
}
