import Foundation

// MARK: - SystemPrompt

/// 構造化されたシステムプロンプト
///
/// DSL を使用して構築された、複数のプロンプトコンポーネントから成る
/// 構造化されたシステムプロンプトです。記述順序がそのまま最終的なプロンプトの
/// 順序となります。
///
/// オプションで `SystemPromptMetadata` を保持し、UI 表示やカタログ管理に
/// 活用できます。
///
/// ## 使用例
///
/// ```swift
/// // メタデータなし（従来の Prompt と同等）
/// let prompt = SystemPrompt {
///     PromptComponent.role("データ分析の専門家")
///     PromptComponent.objective("テキストからユーザー情報を抽出する")
///     PromptComponent.context("日本語の SNS 投稿が入力される")
///
///     PromptComponent.instruction("名前は敬称を除いて抽出する")
///     PromptComponent.instruction("年齢は数値のみ抽出する")
///
///     PromptComponent.constraint("推測はしない")
///     PromptComponent.important("不明な場合は null を返す")
///
///     PromptComponent.example(
///         input: "佐藤花子さん（28）は東京在住",
///         output: #"{"name": "佐藤花子", "age": 28}"#
///     )
/// }
///
/// // メタデータ付き（カタログ登録用）
/// let catalogPrompt = SystemPrompt(
///     "Researcher",
///     description: "情報収集、分析、統合タスクに最適化",
///     iconName: "magnifyingglass",
///     tags: ["research", "analysis"]
/// ) {
///     PromptComponent.role("expert research assistant")
///     PromptComponent.objective("Gather and synthesize information")
/// }
///
/// let result: UserInfo = try await client.generate(
///     prompt: prompt,
///     model: .sonnet
/// )
/// ```
///
/// ## レンダリング
///
/// `render()` メソッドを呼び出すと、各コンポーネントが XML タグ形式で
/// レンダリングされ、記述順に結合されます。
///
/// ```xml
/// <role>
/// データ分析の専門家
/// </role>
///
/// <objective>
/// テキストからユーザー情報を抽出する
/// </objective>
///
/// <context>
/// 日本語の SNS 投稿が入力される
/// </context>
///
/// ...
/// ```
public struct SystemPrompt: Sendable, Equatable, Codable {

    // MARK: - Properties

    /// UI 表示用メタデータ（オプション）
    public let metadata: SystemPromptMetadata?

    /// プロンプトを構成するコンポーネントの配列（記述順）
    public let components: [PromptComponent]

    // MARK: - Initializers

    /// DSL を使用してシステムプロンプトを構築（メタデータなし）
    ///
    /// Result Builder を使用して、宣言的にプロンプトを構築します。
    /// コンポーネントの記述順序がそのままプロンプトの順序になります。
    ///
    /// - Parameter builder: プロンプトコンポーネントを構築するクロージャ
    ///
    /// ## 使用例
    /// ```swift
    /// let prompt = SystemPrompt {
    ///     PromptComponent.role("データ分析の専門家")
    ///     PromptComponent.objective("情報抽出")
    ///     PromptComponent.instruction("名前を抽出する")
    /// }
    /// ```
    public init(@SystemPromptBuilder _ builder: () -> [PromptComponent]) {
        self.metadata = nil
        self.components = builder()
    }

    /// メタデータ付きでシステムプロンプトを構築
    ///
    /// カタログ登録用のプロンプトを作成する場合に使用します。
    ///
    /// - Parameters:
    ///   - name: 表示名
    ///   - description: 説明文
    ///   - iconName: SF Symbols アイコン名
    ///   - tags: タグ（カテゴリ分類用）
    ///   - builder: プロンプトコンポーネントを構築するクロージャ
    ///
    /// ## 使用例
    /// ```swift
    /// let prompt = SystemPrompt(
    ///     "Researcher",
    ///     description: "情報収集・分析タスクに最適化",
    ///     iconName: "magnifyingglass",
    ///     tags: ["research"]
    /// ) {
    ///     PromptComponent.role("expert research assistant")
    /// }
    /// ```
    public init(
        _ name: String,
        description: String,
        iconName: String,
        tags: [String] = [],
        @SystemPromptBuilder _ builder: () -> [PromptComponent]
    ) {
        let id = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
        self.metadata = SystemPromptMetadata(
            id: id,
            name: name,
            description: description,
            iconName: iconName,
            tags: tags
        )
        self.components = builder()
    }

    /// コンポーネント配列から直接初期化
    ///
    /// プログラマティックにプロンプトを構築する場合に使用します。
    ///
    /// - Parameters:
    ///   - components: プロンプトコンポーネントの配列
    ///   - metadata: メタデータ（オプション）
    ///
    /// ## 使用例
    /// ```swift
    /// let components: [PromptComponent] = [
    ///     .objective("情報抽出"),
    ///     .instruction("名前を抽出する")
    /// ]
    /// let prompt = SystemPrompt(components: components)
    /// ```
    public init(components: [PromptComponent], metadata: SystemPromptMetadata? = nil) {
        self.metadata = metadata
        self.components = components
    }

    // MARK: - Rendering

    /// プロンプトを文字列としてレンダリング
    ///
    /// 各コンポーネントを XML タグ形式でレンダリングし、
    /// 空行で区切って結合します。コンポーネントの記述順序が保持されます。
    ///
    /// - Returns: レンダリングされたプロンプト文字列
    public func render() -> String {
        components
            .map { $0.render() }
            .joined(separator: "\n\n")
    }

    // MARK: - Computed Properties

    /// プロンプトが空かどうか
    public var isEmpty: Bool {
        components.isEmpty
    }

    /// コンポーネントの数
    public var count: Int {
        components.count
    }
}

// MARK: - CustomStringConvertible

extension SystemPrompt: CustomStringConvertible {
    public var description: String {
        render()
    }
}

// MARK: - ExpressibleByStringLiteral

extension SystemPrompt: ExpressibleByStringLiteral {
    /// 文字列リテラルからシステムプロンプトを作成
    ///
    /// 単純な文字列をプロンプトとして使用する場合の後方互換性のために提供されます。
    /// 文字列は `context` コンポーネントとして扱われます。
    ///
    /// - Parameter value: プロンプト文字列
    ///
    /// ## 使用例
    /// ```swift
    /// let prompt: SystemPrompt = "山田太郎さんは35歳です"
    /// ```
    public init(stringLiteral value: String) {
        self.metadata = nil
        self.components = [.context(value)]
    }
}

// MARK: - SystemPrompt Combination

extension SystemPrompt {
    /// 2つのシステムプロンプトを結合
    ///
    /// メタデータは左辺のものが保持されます。
    ///
    /// - Parameters:
    ///   - lhs: 最初のプロンプト
    ///   - rhs: 追加するプロンプト
    /// - Returns: 結合されたプロンプト
    public static func + (lhs: SystemPrompt, rhs: SystemPrompt) -> SystemPrompt {
        SystemPrompt(components: lhs.components + rhs.components, metadata: lhs.metadata)
    }

    /// プロンプトにコンポーネントを追加
    ///
    /// - Parameters:
    ///   - lhs: プロンプト
    ///   - rhs: 追加するコンポーネント
    /// - Returns: コンポーネントが追加されたプロンプト
    public static func + (lhs: SystemPrompt, rhs: PromptComponent) -> SystemPrompt {
        SystemPrompt(components: lhs.components + [rhs], metadata: lhs.metadata)
    }

    /// 別のプロンプトを追加した新しいプロンプトを返す
    ///
    /// - Parameter other: 追加するプロンプト
    /// - Returns: 結合されたプロンプト
    public func appending(_ other: SystemPrompt) -> SystemPrompt {
        self + other
    }

    /// コンポーネントを追加した新しいプロンプトを返す
    ///
    /// - Parameter component: 追加するコンポーネント
    /// - Returns: コンポーネントが追加されたプロンプト
    public func appending(_ component: PromptComponent) -> SystemPrompt {
        self + component
    }

    /// コンポーネントを追加した新しいプロンプトを返す
    ///
    /// メタデータを保持しつつ、追加のコンポーネントで拡張します。
    ///
    /// - Parameter builder: 追加するコンポーネントを構築するクロージャ
    /// - Returns: コンポーネントが追加されたプロンプト
    public func modified(@SystemPromptBuilder with builder: () -> [PromptComponent]) -> SystemPrompt {
        SystemPrompt(components: components + builder(), metadata: metadata)
    }
}

// MARK: - Filtering and Transformation

extension SystemPrompt {
    /// 特定のタイプのコンポーネントのみを抽出
    ///
    /// - Parameter predicate: フィルタ条件
    /// - Returns: フィルタされたプロンプト
    public func filter(_ predicate: (PromptComponent) -> Bool) -> SystemPrompt {
        SystemPrompt(components: components.filter(predicate), metadata: metadata)
    }

    /// 特定のタグ名を持つコンポーネントのみを抽出
    ///
    /// - Parameter tagName: 抽出するタグ名
    /// - Returns: フィルタされたプロンプト
    ///
    /// ## 使用例
    /// ```swift
    /// let instructions = prompt.components(withTag: "instruction")
    /// ```
    public func components(withTag tagName: String) -> SystemPrompt {
        filter { $0.tagName == tagName }
    }
}

// MARK: - LLMInputProtocol Conformance

extension SystemPrompt: LLMInputProtocol {
    /// SystemPrompt 自体をプロンプトとして返す
    public var prompt: SystemPrompt { self }
}
