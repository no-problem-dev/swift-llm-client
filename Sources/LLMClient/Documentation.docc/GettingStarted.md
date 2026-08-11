# Getting Started with LLMClient

Go from a Swift type to a decoded model response, then add prompts, images and conversation history.

## Overview

This walkthrough uses `LLMClient` only. Tool calling lives in `LLMTool` and is covered
separately; see <doc:ModuleLayout> for the full split.

## Add the dependency

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-llm-client.git",
        from: "3.0.0"
    )
]
```

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "LLMClient", package: "swift-llm-client"),
        .product(name: "LLMTool",   package: "swift-llm-client"),
    ]
)
```

## 1. Describe the answer you want

`@Structured` makes a type conform to ``StructuredProtocol`` and synthesises its `jsonSchema`.
`@StructuredField` supplies the per-field description and constraints.

The description strings are not comments. They are sent to the model as part of the schema, and
they are the main lever you have over field-level accuracy — write them as instructions.

```swift
import LLMClient

@Structured("A cooking recipe")
struct Recipe {
    @StructuredField("Dish name")
    var name: String

    @StructuredField("Ingredients, each with its quantity")
    var ingredients: [String]

    @StructuredField("Total cooking time in minutes", .minimum(1), .maximum(300))
    var cookingMinutes: Int

    @StructuredField("Difficulty", .enum(["easy", "medium", "hard"]))
    var difficulty: String
}
```

Constraints such as `.minimum` and `.enum` are emitted as JSON Schema keywords where the
provider supports them. Where it does not, ``ProviderSchemaAdapter`` removes the keyword and
records it in ``SchemaAdaptationResult`` rather than sending a request the provider will reject.

## 2. Generate

Take any provider implementation as a ``StructuredLLMClient`` and call `generate`.

```swift
// Provider implementations ship in separate packages.
let client: any StructuredLLMClient<LLMModel> = MyProviderClient(apiKey: apiKey)

let recipe: Recipe = try await client.generate(
    input: "How do I make a simple aglio e olio?",
    model: .claude(.sonnet)
)

print(recipe.name)           // "Aglio e Olio"
print(recipe.cookingMinutes) // 15
```

`generate` discards the usage numbers. If you need to meter or bill, use `generateWithUsage`
and keep the ``GenerationResult`` — token counts cannot be reconstructed from the decoded value.

```swift
let result: GenerationResult<Recipe> = try await client.generateWithUsage(
    input: "How do I make a simple aglio e olio?",
    model: .claude(.sonnet)
)

print(result.result.name)
print(result.usage.inputTokens)
print(result.usage.outputTokens)
```

## 3. Shape the system prompt

``SystemPrompt`` composes ``PromptComponent`` values and renders them as XML-tagged sections.
The order in the builder is the order the model sees, so treat it as part of the prompt.

```swift
let systemPrompt = SystemPrompt {
    PromptComponent.role("An experienced recipe developer")
    PromptComponent.objective("Extract a structured recipe from the user's request")
    PromptComponent.constraint("Always give ingredient quantities as concrete numbers")
    PromptComponent.example(
        input: "I want to make carbonara",
        output: #"{"name":"Carbonara","cookingMinutes":20,"difficulty":"medium"}"#
    )
}

let recipe: Recipe = try await client.generate(
    input: "A proper beef stew",
    model: .claude(.sonnet),
    systemPrompt: systemPrompt
)
```

A system prompt that is stable across requests is also what makes prompt caching pay off; see
``PromptCachePolicy``.

## 4. Send images, audio or video

``LLMInput`` combines text with attachments. The model must actually support the modality —
check the model's profile before sending, or the provider will reject the request.

```swift
let image = ImageContent.base64(imageData, mediaType: .jpeg)

let input = LLMInput(
    "Read this recipe card and extract the recipe.",
    images: [image]
)

let recipe: Recipe = try await client.generate(
    input: input,
    model: .gemini(.flash36)
)
```

## 5. Continue a conversation

For multiple turns, pass the whole message array. Each call is stateless — the model sees only
what you send, so history is yours to keep.

```swift
var messages: [LLMMessage] = []

messages.append(.user("Suggest three things to do in Tokyo."))
let first: CityTips = try await client.generate(
    messages: messages,
    model: .claude(.sonnet)
)

messages.append(.assistant(first.summary))
messages.append(.user("Which of those is best with small children?"))
let second: CityTips = try await client.generate(
    messages: messages,
    model: .claude(.sonnet)
)
```

Growing an array by hand gets tedious fast, and it is easy to forget to append the assistant
turn. `LLMChat` does the bookkeeping and hands back the message to append along with the result.

## Next steps

- `LLMTool` for function calling with the `@Tool` macro.
- `LLMAgentStep` for driving an agent loop a step at a time.
- `LLMContext` for showing how much of the context window is left.
