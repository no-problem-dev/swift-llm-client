import Testing
@testable import LLMClient

/// 提供元をまたいだモデル一覧の組み立てと、保存済み ID の読み戻し。
///
/// `Preset` は提供元ごとに別の型なので、そのままでは 1 つの配列に入らない。
/// 記述子へ潰して初めて「どの提供元のものか知らないまま並べる」ことができる。
@Suite("Model Catalog")
struct ModelCatalogTests {

    // MARK: - globalID

    /// `rawValue` は提供元の中でしか一意でない。保存するのは `globalID` の側。
    @Test("globalID は提供元で名前空間を分ける")
    func globalIDIsNamespacedByProvider() {
        #expect(GeminiModel.Preset.flashLite31.globalID == "gemini:flashLite31")
        #expect(GPTModel.Preset.gpt5_4Mini.globalID == "gpt:gpt5_4Mini")
    }

    @Test("globalID は読み戻せる")
    func globalIDRoundTrips() {
        let preset = GeminiModel.Preset.flashLite31
        #expect(GeminiModel.Preset(globalID: preset.globalID) == preset)
    }

    /// 他の提供元の ID を渡されても、自分のものとして解釈しない。
    @Test("他の提供元の globalID は読み戻さない")
    func globalIDRejectsAnotherProvider() {
        #expect(GeminiModel.Preset(globalID: "gpt:gpt5_4Mini") == nil)
        #expect(GPTModel.Preset(globalID: "gemini:flashLite31") == nil)
    }

    @Test("形が違う globalID は読み戻さない")
    func globalIDRejectsMalformedInput() {
        #expect(GeminiModel.Preset(globalID: "flashLite31") == nil)
        #expect(GeminiModel.Preset(globalID: "gemini:nonexistent") == nil)
    }

    // MARK: - providerID

    /// 記述子から読んだ提供元名と `LLMModel` の case 名を揃えてある。
    /// ずれると、同じ提供元を指す 2 つの綴りが生まれる。
    @Test("providerID は LLMModel の case 名に揃っている")
    func providerIDsMatchLLMModelCases() {
        #expect(ClaudeModel.Preset.providerID == "claude")
        #expect(GPTModel.Preset.providerID == "gpt")
        #expect(GeminiModel.Preset.providerID == "gemini")
        #expect(DeepSeekModel.Preset.providerID == "deepseek")
        #expect(GrokModel.Preset.providerID == "grok")
        #expect(GroqModel.Preset.providerID == "groq")
        #expect(MistralModel.Preset.providerID == "mistral")
    }

    // MARK: - 記述子

    /// 記述子は preset が既に持っていた値を写すだけ。新しい情報を足さない。
    @Test("記述子は preset の値をそのまま写す")
    func descriptorCopiesPresetValues() {
        let preset = GeminiModel.Preset.flashLite31
        let descriptor = preset.descriptor

        #expect(descriptor.id == preset.globalID)
        #expect(descriptor.providerID == "gemini")
        #expect(descriptor.modelID == preset.model.id)
        #expect(descriptor.displayName == preset.displayName)
        #expect(descriptor.shortName == preset.shortName)
        #expect(descriptor.profile == preset.profile)
    }

    @Test("descriptors は allCases と同じ数だけ出る")
    func descriptorsCoverAllCases() {
        #expect(GeminiModel.Preset.descriptors.count == GeminiModel.Preset.allCases.count)
        #expect(GPTModel.Preset.descriptors.count == GPTModel.Preset.allCases.count)
    }

    // MARK: - カタログ

    private var catalog: ModelCatalog {
        ModelCatalog(
            models: GeminiModel.Preset.descriptors + GPTModel.Preset.descriptors,
            defaultModelID: GeminiModel.Preset.flashLite31.globalID
        )
    }

    @Test("提供元ごとに絞り込める")
    func modelsAreFilteredByProvider() {
        #expect(catalog.models(providerID: "gemini").count == GeminiModel.Preset.allCases.count)
        #expect(catalog.models(providerID: "gpt").count == GPTModel.Preset.allCases.count)
        #expect(catalog.models(providerID: "unknown").isEmpty)
    }

    /// 画面が節に分けるときの順。並べ替えはしないので、渡した順のまま出る。
    @Test("providerIDs は出てきた順で重複しない")
    func providerIDsAreUniqueAndOrdered() {
        #expect(catalog.providerIDs == ["gemini", "gpt"])
    }

    @Test("id からモデルを引ける")
    func modelIsFoundByID() {
        let id = GPTModel.Preset.gpt5_4Mini.globalID
        #expect(catalog.model(id: id)?.modelID == GPTModel.Preset.gpt5_4Mini.model.id)
        #expect(catalog.model(id: "gemini:nonexistent") == nil)
    }

    // MARK: - 保存済み ID の解決

    @Test("今もあるモデルはそのまま返る")
    func resolveKeepsAKnownModel() {
        let id = GPTModel.Preset.gpt5_4Mini.globalID
        #expect(catalog.resolve(id) == id)
    }

    /// 提供が終わったモデルの ID が設定に残っていても、選べないものを返さない。
    @Test("無くなったモデルは既定へ落ちる")
    func resolveFallsBackWhenTheModelIsGone() {
        #expect(catalog.resolve("gemini:removed") == catalog.defaultModelID)
        #expect(catalog.resolve(nil) == catalog.defaultModelID)
    }

    /// 既定に指定した ID 自体が一覧に無いこともある。そのときも「無いものを既定にする」
    /// のではなく、実在する先頭へ寄せる。
    @Test("既定が一覧に無ければ先頭を既定にする")
    func defaultFallsBackToTheFirstModel() {
        let catalog = ModelCatalog(
            models: GeminiModel.Preset.descriptors,
            defaultModelID: "gpt:gpt5_4Mini"
        )

        #expect(catalog.defaultModelID == GeminiModel.Preset.allCases[0].globalID)
        #expect(catalog.model(id: catalog.defaultModelID) != nil)
    }
}
