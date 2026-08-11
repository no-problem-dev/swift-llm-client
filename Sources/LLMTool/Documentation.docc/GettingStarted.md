# Getting Started with LLMTool

Define a tool with the `@Tool` macro, let a model choose it, and run it safely.

## Add the dependency

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-llm-client.git",
        from: "3.0.0"
    )
]

.target(
    name: "MyApp",
    dependencies: [
        .product(name: "LLMTool", package: "swift-llm-client"),
    ]
)
```

## 1. Define a tool

Apply `@Tool` to a struct or class, mark the model-visible inputs with `@ToolArgument`, and put
the work in `call()`.

```swift
import LLMTool

@Tool("Return the current weather for a given city")
struct GetWeather {
    // Not annotated, so it is configuration: the model neither sees nor supplies it.
    var apiKey: String

    @ToolArgument("City name, in English or Japanese")
    var city: String

    @ToolArgument("Temperature unit", .enum(["celsius", "fahrenheit"]))
    var unit: String?

    func call() async throws -> String {
        "\(city): sunny, 25°C"
    }
}
```

The macro description and each argument description are sent to the model verbatim. They decide
whether the tool gets picked at all, so write them as instructions rather than as labels.

An optional argument tells the model it may omit the value. A non-optional one does not — it is
emitted as required, and the model will invent something rather than leave it out.

A tool with no inputs declares nothing; ``EmptyArguments`` is used automatically.

```swift
@Tool("Return the current date and time in ISO 8601")
struct GetCurrentTime {
    func call() async throws -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
```

## 2. Build a tool set

``ToolSet`` is a result builder, so conditionals and loops work.

```swift
let tools = ToolSet {
    GetWeather(apiKey: weatherApiKey)
    GetCurrentTime()

    if userHasPremium {
        AdvancedSearchTool(index: searchIndex)
    }

    for tool in dynamicTools {
        tool
    }
}
```

Every tool definition you include is serialised into the request and charged as input tokens on
every turn, so the set is a context-window cost, not a free list. Gate large tools behind
conditionals rather than shipping them all.

## 3. Plan, then execute

``ToolCallableClient`` asks the model which tools to call with which arguments. `planToolCalls`
does not run anything — running is a separate, explicit step.

```swift
let plan = try await client.planToolCalls(
    prompt: "Compare the weather in Tokyo and Osaka.",
    model: .claude(.sonnet),
    tools: tools
)

for call in plan.toolCalls {
    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    print("\(call.name) → \(result.stringValue)")
}
```

A model may return several calls in one response. Treat them as a set to be satisfied, not as a
sequence with meaning: unless a provider documents otherwise, the order carries no dependency
information, and running them concurrently is usually fine.

## 4. Decode arguments

``ToolCall/decodeArguments(as:)`` decodes into any `Decodable` type.

```swift
struct WeatherArgs: Decodable {
    let city: String
    let unit: String?
}

for call in plan.toolCalls where call.name == "get_weather" {
    let args = try call.decodeArguments(as: WeatherArgs.self)
    print(args.city)
}
```

Key-path access works too, when a whole type is more than you need.

```swift
let args = try call.argumentsJSON()
if let city = args.string("city") {
    print(city)
}
```

## 5. Feed the results back

To continue the conversation, the history must contain both the assistant's tool calls and the
matching results. Each result is matched to its call by `toolCallId`; drop one, or reuse an id,
and providers reject the request.

```swift
var messages: [LLMMessage] = [
    .user("What's the temperature in Tokyo right now?"),
]

let plan = try await client.planToolCalls(
    messages: messages,
    model: .claude(.sonnet),
    tools: tools
)

var toolResults: [(toolCallId: String, name: String, content: ToolResultContent)] = []
for call in plan.toolCalls {
    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    toolResults.append((toolCallId: call.id, name: call.name, content: .success(result.stringValue)))
}

messages.append(.toolUses(plan.toolCalls.map { (id: $0.id, name: $0.name, input: $0.arguments) }))
messages.append(.toolResults(toolResults))
```

When a tool fails, send `.failure` back rather than throwing out of the loop. The model can
usually recover — retry with different arguments, or explain the failure to the user — and
throwing discards a turn you have already paid for.

## Next steps

`LLMAgentStep` drives the plan-execute-continue cycle a step at a time, with streaming events.
