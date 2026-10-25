#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The builtin schema for `type` as compact JSON with sorted keys, or `nil` if there isn't one.
private func json(for type: Any.Type) throws -> String? {
    guard let schema = JSONSchema.builtin(for: type) else { return nil }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(schema), as: UTF8.self)
}

private struct User: Codable {
    var id: Int
}

private enum Role: String, Codable {
    case admin
}

@Suite("Builtin schemas")
struct BuiltinSchemasTests {
    @Test("Strings and booleans")
    func stringAndBool() throws {
        #expect(try json(for: String.self) == #"{"type":"string"}"#)
        #expect(try json(for: Bool.self) == #"{"type":"boolean"}"#)
    }

    @Test("Signed integers use the format that fits, with bounds below 32 bits")
    func signedIntegers() throws {
        #expect(try json(for: Int.self) == #"{"format":"int64","type":"integer"}"#)
        #expect(try json(for: Int64.self) == #"{"format":"int64","type":"integer"}"#)
        #expect(try json(for: Int32.self) == #"{"format":"int32","type":"integer"}"#)
        #expect(try json(for: Int16.self) == #"{"format":"int32","maximum":32767,"minimum":-32768,"type":"integer"}"#)
        #expect(try json(for: Int8.self) == #"{"format":"int32","maximum":127,"minimum":-128,"type":"integer"}"#)
        #expect(try json(for: Int128.self) == #"{"type":"integer"}"#)
    }

    @Test("Unsigned integers have a minimum of zero, and a maximum where it fits")
    func unsignedIntegers() throws {
        #expect(try json(for: UInt.self) == #"{"minimum":0,"type":"integer"}"#)
        #expect(try json(for: UInt64.self) == #"{"minimum":0,"type":"integer"}"#)
        #expect(try json(for: UInt32.self) == #"{"format":"int64","maximum":4294967295,"minimum":0,"type":"integer"}"#)
        #expect(try json(for: UInt16.self) == #"{"format":"int32","maximum":65535,"minimum":0,"type":"integer"}"#)
        #expect(try json(for: UInt8.self) == #"{"format":"int32","maximum":255,"minimum":0,"type":"integer"}"#)
        #expect(try json(for: UInt128.self) == #"{"minimum":0,"type":"integer"}"#)
    }

    @Test("Floating-point types are numbers")
    func floatingPoint() throws {
        #expect(try json(for: Double.self) == #"{"format":"double","type":"number"}"#)
        #expect(try json(for: Float.self) == #"{"format":"float","type":"number"}"#)
        #expect(try json(for: Decimal.self) == #"{"type":"number"}"#)
    }

    @Test("Foundation values that encode as strings carry their format")
    func foundationStrings() throws {
        #expect(try json(for: Date.self) == #"{"format":"date-time","type":"string"}"#)
        #expect(try json(for: UUID.self) == #"{"format":"uuid","type":"string"}"#)
        #expect(try json(for: URL.self) == #"{"format":"uri-reference","type":"string"}"#)
    }

    @Test("Data is a base64 string, as in OpenAPI 3.1, not the old byte format")
    func data() throws {
        let schema = try #require(try json(for: Data.self))
        #expect(schema == #"{"contentEncoding":"base64","type":"string"}"#)
        #expect(!schema.contains("byte"))
    }

    @Test("Containers aren't builtin, since they're described from how they decode")
    func containersArentBuiltin() throws {
        #expect(try json(for: [String].self) == nil)
        #expect(try json(for: Set<Int>.self) == nil)
        #expect(try json(for: [String: Int].self) == nil)
        #expect(try json(for: Int?.self) == nil)
    }

    @Test("App types aren't builtin")
    func appTypesArentBuiltin() throws {
        #expect(try json(for: User.self) == nil)
        #expect(try json(for: Role.self) == nil)
    }

    @Test("Every builtin type that's Codable round-trips through JSON as the schema's type")
    func schemaMatchesEncoding() throws {
        // Encoding a sample of each type checks the table against what `JSONEncoder` really
        // writes, with Vapor's default ISO 8601 dates.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        func encoded(_ value: some Encodable) throws -> String {
            String(decoding: try encoder.encode([value]), as: UTF8.self)
        }

        #expect(try encoded("a") == #"["a"]"#)
        #expect(try encoded(true) == "[true]")
        #expect(try encoded(Int8(-1)) == "[-1]")
        #expect(try encoded(UInt32.max) == "[4294967295]")
        #expect(try encoded(1.5) == "[1.5]")
        #expect(try encoded(Date(timeIntervalSince1970: 0)) == #"["1970-01-01T00:00:00Z"]"#)
        #expect(try encoded(Data([1, 2, 3])) == #"["AQID"]"#)
    }
}
#endif
