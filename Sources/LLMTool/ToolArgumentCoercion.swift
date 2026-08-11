import Foundation
import LLMClient

extension JSONSchema {
    /// Rewrites loosely typed tool arguments into the types this schema declares.
    ///
    /// Small local models routinely emit numbers and booleans as strings, such as
    /// `{"max_results": "10"}`, and a strict `JSONDecoder` rejects that as a type mismatch. Only
    /// fields the schema types as `integer`, `number` or `boolean` are touched, and only when the
    /// incoming value is a string: surrounding whitespace is trimmed and the value is converted,
    /// with `"true"` and `"false"` matched without regard to case. Objects and arrays are walked
    /// recursively, so nested fields are repaired too, but a key the schema does not declare is
    /// left alone, as are strings, nulls, and any string that fails to parse as the declared
    /// type.
    ///
    /// Empty data, JSON that will not parse, and a result that will not re-serialize all return
    /// the input untouched. A payload that does parse comes back re-serialized, so key order and
    /// spacing can differ even where no value changed. The conversion is provider-independent and
    /// every tool execution path shares it.
    ///
    /// - Parameter data: The raw JSON arguments carried by a tool call.
    /// - Returns: The arguments with schema-typed strings converted, or the original data when
    ///   there was nothing to do.
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
