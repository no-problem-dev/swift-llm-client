import Testing
@testable import LLMClient
import Foundation

@Suite("DynamicJSON Tests")
struct DynamicJSONTests {

    // MARK: - Initialization

    @Test func initFromValues() {
        let json = DynamicJSON(values: ["name": "Alice", "age": 30])
        #expect(json.string("name") == "Alice")
        #expect(json.int("age") == 30)
    }

    @Test func initFromData() throws {
        let data = try JSONSerialization.data(withJSONObject: ["city": "Tokyo", "temp": 25.5])
        let json = try DynamicJSON(from: data)
        #expect(json.string("city") == "Tokyo")
        #expect(json.double("temp") == 25.5)
    }

    @Test func initFromJSONString() throws {
        let json = try DynamicJSON(from: #"{"key": "value"}"#)
        #expect(json.string("key") == "value")
    }

    @Test func initFromInvalidData() {
        let data = "not json".data(using: .utf8)!
        #expect(throws: DynamicJSONError.self) {
            try DynamicJSON(from: data)
        }
    }

    @Test func initFromInvalidEncoding() {
        // Invalid encoding is hard to trigger with Swift strings,
        // but we can test the error type exists
        #expect(throws: DynamicJSONError.self) {
            // JSON array, not object
            try DynamicJSON(from: "[1,2,3]".data(using: .utf8)!)
        }
    }

    // MARK: - Type-Safe Accessors

    @Test func stringAccessor() {
        let json = DynamicJSON(values: ["name": "Bob", "age": 25])
        #expect(json.string("name") == "Bob")
        #expect(json.string("age") == nil)  // Int is not String
        #expect(json.string("missing") == nil)
    }

    @Test func intAccessor() {
        let json = DynamicJSON(values: ["count": 42, "price": 9.99])
        #expect(json.int("count") == 42)
        #expect(json.int("price") == 9)  // Double -> Int conversion
        #expect(json.int("missing") == nil)
    }

    @Test func doubleAccessor() {
        let json = DynamicJSON(values: ["price": 9.99, "count": 42])
        #expect(json.double("price") == 9.99)
        #expect(json.double("count") == 42.0)  // Int -> Double conversion
        #expect(json.double("missing") == nil)
    }

    @Test func boolAccessor() {
        let json = DynamicJSON(values: ["active": true, "deleted": false])
        #expect(json.bool("active") == true)
        #expect(json.bool("deleted") == false)
        #expect(json.bool("missing") == nil)
    }

    @Test func stringArrayAccessor() {
        let json = DynamicJSON(values: ["tags": ["swift", "ios"]])
        #expect(json.stringArray("tags") == ["swift", "ios"])
        #expect(json.stringArray("missing") == nil)
    }

    @Test func intArrayAccessor() {
        let json = DynamicJSON(values: [
            "ids": [1, 2, 3],
            "doubles": [1.0, 2.0, 3.0],
        ])
        #expect(json.intArray("ids") == [1, 2, 3])
        #expect(json.intArray("doubles") == [1, 2, 3])  // Double -> Int
        #expect(json.intArray("missing") == nil)
    }

    // MARK: - Nested Access

    @Test func nestedAccess() {
        let json = DynamicJSON(values: [
            "address": ["city": "Tokyo", "zip": "100-0001"] as [String: Any],
        ])
        let address = json.nested("address")
        #expect(address != nil)
        #expect(address?.string("city") == "Tokyo")
        #expect(json.nested("missing") == nil)
    }

    @Test func nestedArrayAccess() {
        let json = DynamicJSON(values: [
            "items": [
                ["name": "A", "price": 100],
                ["name": "B", "price": 200],
            ] as [[String: Any]],
        ])
        let items = json.nestedArray("items")
        #expect(items?.count == 2)
        #expect(items?[0].string("name") == "A")
        #expect(items?[1].int("price") == 200)
    }

    // MARK: - Utility Methods

    @Test func subscriptAccess() {
        let json = DynamicJSON(values: ["key": "value"])
        #expect(json["key"] as? String == "value")
        #expect(json["missing"] == nil)
    }

    @Test func keysProperty() {
        let json = DynamicJSON(values: ["a": 1, "b": 2, "c": 3])
        #expect(Set(json.keys) == Set(["a", "b", "c"]))
    }

    @Test func hasKey() {
        let json = DynamicJSON(values: ["exists": true])
        #expect(json.hasKey("exists"))
        #expect(!json.hasKey("missing"))
    }

    @Test func rawValues() {
        let original: [String: Any] = ["x": 1, "y": "hello"]
        let json = DynamicJSON(values: original)
        #expect(json.rawValues["x"] as? Int == 1)
        #expect(json.rawValues["y"] as? String == "hello")
    }

    // MARK: - Empty Data

    @Test func emptyObject() throws {
        let json = try DynamicJSON(from: "{}".data(using: .utf8)!)
        #expect(json.keys.isEmpty)
        #expect(json.string("any") == nil)
    }

    // MARK: - Debug Description

    @Test func debugDescription() {
        let json = DynamicJSON(values: ["name": "test"])
        let desc = json.debugDescription
        #expect(desc.contains("DynamicJSON"))
    }
}
