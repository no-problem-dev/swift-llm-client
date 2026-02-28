import Testing
@testable import LLMTool
@testable import LLMClient
import Foundation

@Suite("DynamicTool Tests")
struct DynamicToolTests {

    // MARK: - Builder DSL Init

    @Test func builderDSLInit() async throws {
        let tool = DynamicTool("get_weather", description: "天気を取得") {
            JSONSchema.string(description: "都市名").named("city")
            JSONSchema.enum(["celsius", "fahrenheit"], description: "単位")
                .named("unit").optional()
        } handler: { args in
            let city = args.string("city") ?? "unknown"
            return .text("Weather in \(city): 25°C")
        }

        #expect(tool.toolName == "get_weather")
        #expect(tool.toolDescription == "天気を取得")
        #expect(tool.inputSchema.type == .object)
        #expect(tool.inputSchema.properties?["city"] != nil)
        #expect(tool.inputSchema.properties?["unit"] != nil)
        #expect(tool.inputSchema.required == ["city"])

        // Execute
        let argsData = try JSONSerialization.data(withJSONObject: ["city": "Tokyo"])
        let result = try await tool.execute(with: argsData)
        #expect(result == .text("Weather in Tokyo: 25°C"))
    }

    @Test func builderDSLAllFieldTypes() {
        let tool = DynamicTool("test_types", description: "All types") {
            JSONSchema.string(description: "str").named("str")
            JSONSchema.integer(description: "int").named("int")
            JSONSchema.number(description: "num").named("num")
            JSONSchema.boolean(description: "bool").named("bool")
            JSONSchema.array(description: "arr", items: .string()).named("arr")
            JSONSchema.enum(["a", "b"], description: "enum").named("enum")
        } handler: { _ in .text("ok") }

        #expect(tool.inputSchema.properties?.count == 6)
        #expect(tool.inputSchema.required?.count == 6)
    }

    // MARK: - Raw Handler Init

    @Test func rawHandlerInit() async throws {
        let tool = DynamicTool("raw_tool", description: "Raw handler") {
            JSONSchema.string().named("input")
        } rawHandler: { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let input = json?["input"] as? String ?? ""
            return .text("raw: \(input)")
        }

        let argsData = try JSONSerialization.data(withJSONObject: ["input": "hello"])
        let result = try await tool.execute(with: argsData)
        #expect(result == .text("raw: hello"))
    }

    // MARK: - Direct Schema Init

    @Test func directSchemaInit() async throws {
        let schema = JSONSchema.object(
            properties: ["x": .integer()],
            required: ["x"]
        )

        let tool = DynamicTool(
            name: "direct_tool",
            description: "Direct schema",
            inputSchema: schema
        ) { args in
            let x = args.int("x") ?? 0
            return .text("x=\(x)")
        }

        #expect(tool.toolName == "direct_tool")

        let argsData = try JSONSerialization.data(withJSONObject: ["x": 42])
        let result = try await tool.execute(with: argsData)
        #expect(result == .text("x=42"))
    }

    // MARK: - No Parameters Init

    @Test func noParametersInit() async throws {
        let tool = DynamicTool("get_time", description: "現在時刻を取得") {
            .text("2026-03-01T00:00:00Z")
        }

        #expect(tool.toolName == "get_time")
        #expect(tool.inputSchema.type == .object)
        #expect(tool.inputSchema.properties?.isEmpty == true)

        let result = try await tool.execute(with: "{}".data(using: .utf8)!)
        #expect(result == .text("2026-03-01T00:00:00Z"))
    }

    // MARK: - Annotations

    @Test func annotationsPreserved() {
        let tool = DynamicTool(
            "annotated_tool",
            description: "With annotations",
            annotations: .readOnly
        ) {
            .text("ok")
        }

        #expect(tool.annotations.readOnlyHint == true)
    }

    @Test func customAnnotations() {
        let annotations = ToolAnnotations(
            title: "My Tool",
            readOnlyHint: false,
            destructiveHint: true,
            idempotentHint: false,
            openWorldHint: true
        )

        let tool = DynamicTool(
            "custom_tool",
            description: "Custom",
            annotations: annotations
        ) {
            JSONSchema.string().named("x")
        } handler: { _ in .text("ok") }

        #expect(tool.annotations == annotations)
    }

    // MARK: - ToolSet Integration

    @Test func toolSetIntegration() async throws {
        let dynamicTool = DynamicTool("dynamic", description: "Dynamic tool") {
            JSONSchema.string().named("input")
        } handler: { args in
            .text("dynamic: \(args.string("input") ?? "")")
        }

        let noParamTool = DynamicTool("no_param", description: "No param") {
            .text("no param result")
        }

        let toolSet = ToolSet {
            dynamicTool
            noParamTool
        }

        #expect(toolSet.count == 2)
        #expect(toolSet.toolNames.contains("dynamic"))
        #expect(toolSet.toolNames.contains("no_param"))

        // Execute through ToolSet
        let data = try JSONSerialization.data(withJSONObject: ["input": "test"])
        let result = try await toolSet.execute(toolNamed: "dynamic", with: data)
        #expect(result == .text("dynamic: test"))
    }

    // MARK: - Tool Protocol Conformance

    @Test func toolProtocolConvenience() {
        let tool = DynamicTool("my_tool", description: "My tool description") {
            .text("ok")
        }

        #expect(tool.name == "my_tool")
        #expect(tool.description == "My tool description")
    }

    // MARK: - Error Handling

    @Test func handlerThrowsError() async {
        struct TestError: Error {}

        let tool = DynamicTool("error_tool", description: "Throws") {
            JSONSchema.string().named("x")
        } handler: { _ in
            throw TestError()
        }

        let data = try! JSONSerialization.data(withJSONObject: ["x": "val"])
        do {
            _ = try await tool.execute(with: data)
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is TestError)
        }
    }
}
