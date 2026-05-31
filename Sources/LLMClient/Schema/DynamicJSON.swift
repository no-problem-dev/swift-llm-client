import Foundation
import StructuredDataCore
import JSONParsing

// MARK: - DynamicJSON

/// 動的 JSON データの型安全アクセサ
///
/// LLM から返された JSON データやツール引数を動的に扱うための型です。
/// 内部表現は swift-structured-data の ``StructuredValue`` に統一されており、
/// 数値の精度とキー順序を保持します（独自の `[String: Any]` 実装は廃止）。
///
/// ```swift
/// let json = try DynamicJSON(from: data)
/// let name = json.string("name")
/// let city = json.nested("address")?.string("city")
/// ```
public struct DynamicJSON: Sendable {
    /// 統一中間表現。新 API を直接使いたい場合に利用する。
    public let structuredValue: StructuredValue

    public init(value: StructuredValue) {
        self.structuredValue = value
    }

    public init(values: [String: Any]) {
        self.structuredValue = .object(OrderedObject(values.map { ($0.key, DynamicJSON.structured(from: $0.value)) }))
    }

    /// JSON データからデコードして初期化（トップレベルはオブジェクトを要求）。
    public init(from data: Data) throws {
        let value: StructuredValue
        do {
            value = try JSONParser().parse(data)
        } catch {
            throw DynamicJSONError.invalidJSON
        }
        guard case .object = value else { throw DynamicJSONError.invalidJSON }
        self.structuredValue = value
    }

    public init(from jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else { throw DynamicJSONError.invalidEncoding }
        try self.init(from: data)
    }

    // MARK: - Access

    public subscript(key: String) -> Any? {
        guard let child = structuredValue.objectValue?[key] else { return nil }
        return DynamicJSON.any(from: child)
    }

    public func string(_ key: String) -> String? { structuredValue.string(key) }
    public func int(_ key: String) -> Int? { structuredValue.int(key) }
    public func double(_ key: String) -> Double? { structuredValue.double(key) }
    public func bool(_ key: String) -> Bool? { structuredValue.bool(key) }

    public func stringArray(_ key: String) -> [String]? {
        guard let array = structuredValue.array(key) else { return nil }
        return allOrNothing(array) { $0.stringValue }
    }

    public func intArray(_ key: String) -> [Int]? {
        guard let array = structuredValue.array(key) else { return nil }
        return allOrNothing(array) { $0.int }
    }

    public func nested(_ key: String) -> DynamicJSON? {
        guard let child = structuredValue.objectValue?[key], case .object = child else { return nil }
        return DynamicJSON(value: child)
    }

    public func nestedArray(_ key: String) -> [DynamicJSON]? {
        guard let array = structuredValue.array(key) else { return nil }
        return allOrNothing(array) { element in
            if case .object = element { return DynamicJSON(value: element) } else { return nil }
        }
    }

    public var keys: [String] { structuredValue.keys }
    public func hasKey(_ key: String) -> Bool { structuredValue.has(key) }

    public var rawValues: [String: Any] {
        guard case .object(let object) = structuredValue else { return [:] }
        return object.entries.reduce(into: [:]) { $0[$1.key] = DynamicJSON.any(from: $1.value) }
    }

    private func allOrNothing<T>(_ array: [StructuredValue], _ transform: (StructuredValue) -> T?) -> [T]? {
        var result: [T] = []
        result.reserveCapacity(array.count)
        for element in array {
            guard let value = transform(element) else { return nil }
            result.append(value)
        }
        return result
    }
}

// MARK: - Any bridging

extension DynamicJSON {
    /// JSONSerialization 互換の `Any` を ``StructuredValue`` へ変換する。
    static func structured(from any: Any) -> StructuredValue {
        if any is NSNull { return .null }
        if let number = any as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .number(StructuredNumber(unchecked: number.stringValue))
        }
        if let bool = any as? Bool { return .bool(bool) }
        if let string = any as? String { return .string(string) }
        if let array = any as? [Any] { return .array(array.map(structured(from:))) }
        if let dictionary = any as? [String: Any] {
            return .object(OrderedObject(dictionary.map { ($0.key, structured(from: $0.value)) }))
        }
        return .null
    }

    /// ``StructuredValue`` を JSONSerialization 互換の `Any` へ戻す。
    static func any(from value: StructuredValue) -> Any {
        switch value {
        case .null: return NSNull()
        case .bool(let bool): return bool
        case .number(let number): return number.int ?? number.double
        case .string(let string): return string
        case .array(let array): return array.map(any(from:))
        case .object(let object): return object.entries.reduce(into: [String: Any]()) { $0[$1.key] = any(from: $1.value) }
        }
    }
}

// MARK: - Errors

public enum DynamicJSONError: Error, Sendable {
    case invalidJSON
    case invalidEncoding
}

// MARK: - CustomDebugStringConvertible

extension DynamicJSON: CustomDebugStringConvertible {
    public var debugDescription: String {
        let json = JSONSerializer(options: .init(prettyPrinted: true)).string(from: structuredValue)
        return "DynamicJSON: \(json)"
    }
}
