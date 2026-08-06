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

    // MARK: - ReasoningEffort
    //
    // 対応値は実 API を叩いて確かめたもの。非対応の値を送るとリクエストごと
    // 弾かれる（'minimal' is not supported with the 'gpt-5.6-luna' model）。

    @Test("GPT-5.6 系は max まで使えるが minimal は使えない")
    func gpt56SupportsMaxNotMinimal() {
        for model in [GPTModel.gpt5_6Sol, .gpt5_6Terra, .gpt5_6Luna] {
            #expect(model.supports(.max))
            #expect(model.supports(.xhigh))
            #expect(model.supports(.none))
            #expect(!model.supports(.minimal))
        }
    }

    @Test("GPT-5.4 / 5.3 は xhigh まで。max は使えない")
    func gpt54SupportsXhighNotMax() {
        for model in [GPTModel.gpt5_4Mini, .gpt5_4Nano, .gpt5_3Codex] {
            #expect(model.supports(.xhigh))
            #expect(!model.supports(.max))
            #expect(!model.supports(.minimal))
        }
    }

    @Test("o-series は low / medium / high だけ")
    func oSeriesSupportsOnlyThreeLevels() {
        #expect(GPTModel.o4Mini.supports(.low))
        #expect(GPTModel.o4Mini.supports(.high))
        #expect(!GPTModel.o4Mini.supports(.minimal))
        #expect(!GPTModel.o4Mini.supports(.none))
        #expect(!GPTModel.o4Mini.supports(.xhigh))
    }

    @Test("GPT-5.0 系は minimal を使う（none はまだ無い）")
    func gpt50UsesMinimal() {
        #expect(GPTModel.gpt5.supports(.minimal))
        #expect(!GPTModel.gpt5.supports(.none))
    }

    @Test("reasoning 非対応モデルは effort を落とす")
    func nonReasoningModelDropsEffort() {
        #expect(GPTModel.gpt4o.clamped(.medium) == nil)
        #expect(!GPTModel.gpt4o.supports(.low))
    }

    @Test("非対応の effort は近い段に寄せる")
    func unsupportedEffortIsClamped() {
        // max 非対応 → xhigh へ下げる
        #expect(GPTModel.gpt5_4Mini.clamped(.max) == .xhigh)
        // xhigh も max も非対応 → high へ
        #expect(GPTModel.o4Mini.clamped(.max) == .high)
        // minimal 非対応で none がある → none へ
        // （`.none` は Optional.none と紛れるので型を明示する）
        #expect(GPTModel.gpt5_6Luna.clamped(.minimal) == ReasoningEffort.none)
        // minimal も none も非対応（o-series）→ low へ
        #expect(GPTModel.o4Mini.clamped(.minimal) == .low)
        #expect(GPTModel.o4Mini.clamped(.none) == .low)
        // 対応している値はそのまま
        #expect(GPTModel.gpt5_6Sol.clamped(.max) == .max)
        #expect(GPTModel.gpt5_4Mini.clamped(.medium) == .medium)
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
