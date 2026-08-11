# ``LLMTool``

Declare the functions a model may call as Swift types, and keep the arguments type-safe in both directions.

## Overview

Function calling normally costs you a hand-written JSON Schema, a string-keyed dispatch table
and an untyped argument dictionary. `LLMTool` replaces all three: `@Tool` derives the schema
from the type, `ToolSet` does the dispatch, and `@ToolArgument` gives you real properties.

```swift
import LLMTool

@Tool("Get the current weather for a city")
struct GetWeather {
    // A plain stored property is injected configuration.
    // The model never sees it and never supplies it.
    var apiKey: String

    @ToolArgument("City name")
    var city: String

    @ToolArgument("Temperature unit", .enum(["celsius", "fahrenheit"]))
    var unit: String?

    func call() async throws -> String {
        "\(city): sunny, 25°C"
    }
}
```

The split between `@ToolArgument` properties and plain ones is the thing to internalise. Only
the annotated ones become schema properties, so secrets and dependencies can live on the same
type without ever being exposed to the model or hallucinated back at you.

Collect tools with the ``ToolSet`` result builder, which accepts conditionals and loops, then
hand the set to a client:

```swift
let tools = ToolSet {
    GetWeather(apiKey: apiKey)
    SearchWeb()

    if isPremium {
        DeepAnalysis()
    }
}

let plan = try await client.planToolCalls(
    prompt: "What's the weather in Tokyo?",
    model: .claude(.sonnet),
    tools: tools
)

for call in plan.toolCalls {
    let result = try await tools.execute(toolNamed: call.name, with: call.arguments)
    print(result.stringValue)
}
```

`planToolCalls` plans; it does not execute. The model chooses tools and arguments, and you
decide whether to run them — which is what makes confirmation prompts, sandboxing and dry runs
possible. Executing the plan and feeding the results back is the caller's loop, or
`LLMAgentStep`'s.

Adopt ``TurnEndingTool`` on a tool that should stop the loop. An agent runtime looks for that
marker and finishes the turn once the tool returns successfully, instead of sending the result
back for another round.

## Topics

### Essentials

- <doc:GettingStarted>

### Defining tools

- ``Tool``
- ``TurnEndingTool``
- ``ToolDefinition``
- ``EmptyArguments``

### Collecting tools

- ``ToolSet``
- ``ToolSetBuilder``
- ``ToolExecutionError``

### Tool calls

- ``ToolCall``
- ``ToolCallResponse``
- ``ToolCallableClient``
- ``ToolChoice``

### Results

- ``ToolResult``
- ``ToolResultConvertible``
- ``JSONToolResult``
- ``ToolResponse``
- ``DynamicTool``

### Token accounting

- ``TokenCounting``
- ``ToolAnnotations``

### Macros

- ``Tool(_:name:)``
- ``ToolArgument(_:_:)``
- ``ToolExclude()``
