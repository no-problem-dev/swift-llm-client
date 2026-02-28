import Foundation

// MARK: - DynamicJSON

/// 動的 JSON データの型安全アクセサ
///
/// LLM から返された JSON データや、ツール引数として渡された JSON データを
/// 動的に扱うための型です。
/// Dictionary ライクなアクセスと、型安全なヘルパーメソッドを提供します。
///
/// ## 使用例
///
/// ```swift
/// let json = try DynamicJSON(from: data)
///
/// // subscript アクセス
/// let name = json["name"]  // Any?
///
/// // 型安全なアクセス
/// let nameString = json.string("name")  // String?
/// let age = json.int("age")             // Int?
///
/// // ネストされた構造へのアクセス
/// let city = json.nested("address")?.string("city")
/// ```
///
/// - Note: この型は `@unchecked Sendable` です。
///   内部の辞書は `let` で不変であるため、スレッドセーフです。
public struct DynamicJSON: @unchecked Sendable {
    /// 内部の値を保持する辞書
    private let values: [String: Any]

    // MARK: - Initializers

    /// 辞書から初期化
    ///
    /// - Parameter values: フィールド名と値のマッピング
    public init(values: [String: Any]) {
        self.values = values
    }

    /// JSON データからデコードして初期化
    ///
    /// - Parameter data: JSON データ
    /// - Throws: `DynamicJSONError` デコードエラー
    public init(from data: Data) throws {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw DynamicJSONError.invalidJSON
            }
            self.values = json
        } catch is DynamicJSONError {
            throw DynamicJSONError.invalidJSON
        } catch {
            throw DynamicJSONError.invalidJSON
        }
    }

    /// JSON 文字列からデコードして初期化
    ///
    /// - Parameter jsonString: JSON 文字列
    /// - Throws: デコードエラー
    public init(from jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw DynamicJSONError.invalidEncoding
        }
        try self.init(from: data)
    }

    // MARK: - Subscript Access

    /// フィールド値への subscript アクセス
    ///
    /// - Parameter key: フィールド名
    /// - Returns: フィールドの値、または nil
    public subscript(key: String) -> Any? {
        values[key]
    }

    // MARK: - Type-Safe Accessors

    /// 文字列として取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: 文字列値、または nil
    public func string(_ key: String) -> String? {
        values[key] as? String
    }

    /// 整数として取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: 整数値、または nil
    public func int(_ key: String) -> Int? {
        if let intValue = values[key] as? Int {
            return intValue
        }
        // JSON では数値が Double として解釈される場合がある
        if let doubleValue = values[key] as? Double {
            return Int(doubleValue)
        }
        return nil
    }

    /// 浮動小数点数として取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: 浮動小数点数値、または nil
    public func double(_ key: String) -> Double? {
        if let doubleValue = values[key] as? Double {
            return doubleValue
        }
        if let intValue = values[key] as? Int {
            return Double(intValue)
        }
        return nil
    }

    /// 真偽値として取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: 真偽値、または nil
    public func bool(_ key: String) -> Bool? {
        values[key] as? Bool
    }

    /// 文字列配列として取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: 文字列配列、または nil
    public func stringArray(_ key: String) -> [String]? {
        values[key] as? [String]
    }

    /// 整数配列として取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: 整数配列、または nil
    public func intArray(_ key: String) -> [Int]? {
        if let intArray = values[key] as? [Int] {
            return intArray
        }
        // Double 配列を Int 配列に変換
        if let doubleArray = values[key] as? [Double] {
            return doubleArray.map { Int($0) }
        }
        return nil
    }

    /// ネストされたオブジェクトとして取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: ネストされた DynamicJSON、または nil
    public func nested(_ key: String) -> DynamicJSON? {
        guard let dict = values[key] as? [String: Any] else {
            return nil
        }
        return DynamicJSON(values: dict)
    }

    /// ネストされたオブジェクトの配列として取得
    ///
    /// - Parameter key: フィールド名
    /// - Returns: ネストされた DynamicJSON の配列、または nil
    public func nestedArray(_ key: String) -> [DynamicJSON]? {
        guard let array = values[key] as? [[String: Any]] else {
            return nil
        }
        return array.map { DynamicJSON(values: $0) }
    }

    // MARK: - Utility Methods

    /// すべてのキーを取得
    public var keys: [String] {
        Array(values.keys)
    }

    /// 指定されたキーが存在するか確認
    ///
    /// - Parameter key: フィールド名
    /// - Returns: キーが存在する場合 true
    public func hasKey(_ key: String) -> Bool {
        values[key] != nil
    }

    /// 生の辞書として取得
    public var rawValues: [String: Any] {
        values
    }
}

// MARK: - Errors

/// DynamicJSON のエラー
public enum DynamicJSONError: Error, Sendable {
    /// 無効な JSON データ
    case invalidJSON

    /// 無効なエンコーディング
    case invalidEncoding
}

// MARK: - CustomDebugStringConvertible

extension DynamicJSON: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: .prettyPrinted),
              let string = String(data: data, encoding: .utf8) else {
            return "DynamicJSON(\(values.keys.joined(separator: ", ")))"
        }
        return "DynamicJSON: \(string)"
    }
}
