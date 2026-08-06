import Testing
@testable import LLMClient

/// `Preset` は**利用者に選ばせる一覧**なので、提供が終わったモデルを載せない。
///
/// 載っていると選べてしまい、呼んだときに 404
/// （"no longer available to new users"）になる。実際に Gemini 2.5 系で起きた。
@Suite("Model Preset")
struct ModelPresetTests {

    @Test("Gemini の Preset に提供終了モデルが混ざっていない")
    func geminiPresetHasNoRetiredModel() {
        for preset in GeminiModel.Preset.allCases {
            #expect(!preset.model.isRetired, "\(preset.displayName) は提供終了。Preset から外す")
        }
    }

    @Test("提供終了した Gemini モデルは isRetired で見分けられる")
    func retiredGeminiModelsAreMarked() {
        #expect(GeminiModel.pro25.isRetired)
        #expect(GeminiModel.flash25.isRetired)
        #expect(GeminiModel.flashLite25.isRetired)
        #expect(!GeminiModel.flash36.isRetired)
        #expect(!GeminiModel.flashLite31.isRetired)
    }

    /// 保存済みの ID を読み戻せること。提供終了しても case を残す理由がこれ。
    @Test("提供終了モデルの ID も custom に落ちず読み戻せる")
    func retiredIdsStillRoundTrip() {
        #expect(GeminiModel(rawValue: "gemini-2.5-flash-lite") == .flashLite25)
        #expect(GeminiModel(rawValue: "gemini-3.6-flash") == .flash36)
        #expect(GeminiModel(rawValue: "gemini-3.5-flash-lite") == .flashLite35)
    }

    @Test("Preset の model と id が対応している")
    func presetIdsMatchModelIds() {
        #expect(GeminiModel.Preset.flash36.model.id == "gemini-3.6-flash")
        #expect(GeminiModel.Preset.flashLite35.model.id == "gemini-3.5-flash-lite")
        #expect(GPTModel.Preset.gpt5_6Sol.model.id == "gpt-5.6-sol")
        #expect(GPTModel.Preset.gpt5_6Terra.model.id == "gpt-5.6-terra")
        #expect(GPTModel.Preset.gpt5_6Luna.model.id == "gpt-5.6-luna")
    }

    @Test("すべての Preset が profile と表示名を持つ")
    func everyPresetHasProfile() {
        for preset in GeminiModel.Preset.allCases {
            #expect(!preset.displayName.isEmpty)
            #expect(!preset.profile.summary.isEmpty)
        }
        for preset in GPTModel.Preset.allCases {
            #expect(!preset.displayName.isEmpty)
            #expect(!preset.profile.summary.isEmpty)
        }
    }
}
