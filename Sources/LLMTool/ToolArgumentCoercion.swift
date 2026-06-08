import Foundation
import LLMClient

extension JSONSchema {
    /// ツール引数 JSON を、このスキーマに沿って型強制（coerce）する。
    ///
    /// 小型のローカル LLM は数値・真偽値を文字列で出すことがある
    /// （例: `{"max_results": "10"}`）。厳格な `JSONDecoder` はこれを型不一致で
    /// 失敗させるため、スキーマが `integer` / `number` / `boolean` を要求する
    /// フィールドに限って、文字列を対応する型へ変換する。
    ///
    /// スキーマ非対象・変換不能・パース失敗の場合は元データをそのまま返す
    /// （正常な引数を壊さない）。プロバイダー非依存で、全ツール実行経路で共有する。
    public func coerceArguments(_ data: Data) -> Data {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let serialized = try? JSONSerialization.data(withJSONObject: coerce(object))
        else { return data }
        return serialized
    }

    private func coerce(_ value: Any) -> Any {
        switch type {
        case .object:
            guard let dict = value as? [String: Any], let properties else { return value }
            var result = dict
            for (key, sub) in properties where result[key] != nil {
                result[key] = sub.coerce(result[key]!)
            }
            return result

        case .array:
            guard let array = value as? [Any], let items = items?.value else { return value }
            return array.map { items.coerce($0) }

        case .integer:
            if let s = value as? String, let i = Int(s.trimmingCharacters(in: .whitespaces)) { return i }
            return value

        case .number:
            if let s = value as? String, let d = Double(s.trimmingCharacters(in: .whitespaces)) { return d }
            return value

        case .boolean:
            if let s = value as? String {
                switch s.trimmingCharacters(in: .whitespaces).lowercased() {
                case "true": return true
                case "false": return false
                default: return value
                }
            }
            return value

        case .string, .null:
            return value
        }
    }
}
