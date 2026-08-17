import Foundation

// MARK: - Provider conformances

// `providerID` matches the corresponding `LLMModel` case name, so an identifier read out of a
// preset and one read out of an `LLMModel` name the same provider. `modelID` forwards to the
// address the provider already resolves to; none of these add information a preset did not
// publish before.

extension ClaudeModel.Preset: ModelPreset {
    public static var providerID: String { "claude" }
    public var modelID: String { model.id }
}

extension GPTModel.Preset: ModelPreset {
    public static var providerID: String { "gpt" }
    public var modelID: String { model.id }
}

extension GeminiModel.Preset: ModelPreset {
    public static var providerID: String { "gemini" }
    public var modelID: String { model.id }
}

extension DeepSeekModel.Preset: ModelPreset {
    public static var providerID: String { "deepseek" }
    public var modelID: String { model.id }
}

extension GrokModel.Preset: ModelPreset {
    public static var providerID: String { "grok" }
    public var modelID: String { model.id }
}

extension GroqModel.Preset: ModelPreset {
    public static var providerID: String { "groq" }
    public var modelID: String { model.id }
}

extension MistralModel.Preset: ModelPreset {
    public static var providerID: String { "mistral" }
    public var modelID: String { model.id }
}
