#if OpenAPI
import OpenAPIKit
import Testing
// Public, because conforming the public `Decimal` below makes a public conformance.
@testable public import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The schema as compact JSON with sorted keys, so tests can compare it exactly.
private func json(_ schema: JSONSchema?) throws -> String? {
    guard let schema else { return nil }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(schema), as: UTF8.self)
}

/// The schema a generic caller sees, which goes through the protocol witness.
private func genericSchema<T: OpenAPISchemaProvider>(_: T.Type) -> OpenAPISchema {
    T.openAPISchema
}

private enum Role: String, Codable, CaseIterable, OpenAPISchemaProvider {
    case user
    case admin
}

private enum Status: String, CaseIterable, OpenAPISchemaProvider {
    case active
}

/// A string-backed enum that describes itself rather than taking the default.
private enum Color: String, CaseIterable, OpenAPISchemaProvider {
    case red
    case green

    static var openAPISchema: OpenAPISchema { .string(format: .other("color")) }
}

private struct Money: OpenAPISchemaProvider {
    static var openAPISchema: OpenAPISchema { .object(["amount": .string(), "currency": .string()]) }
}

/// String-backed and `CaseIterable`, but with no cases. An enum with no cases can't have a raw type.
private struct NoCases: RawRepresentable, CaseIterable, OpenAPISchemaProvider {
    var rawValue: String
    static var allCases: [NoCases] { [] }
}

private struct User: Codable {
    var id: Int
}

// Conformances are global, so this changes `Decimal` for every test in the process. Only
// `schema(for:)` sees it: `builtin(for:)` doesn't look at providers.
extension Decimal: OpenAPISchemaProvider {
    static var openAPISchema: OpenAPISchema { .string() }
}

@Suite("OpenAPISchemaProvider")
struct OpenAPISchemaProviderTests {
    // MARK: - String enums

    @Test("A string enum is described by its raw values, in declaration order")
    func enumDefault() throws {
        #expect(try json(Role.openAPISchema.schema) == #"{"enum":["user","admin"],"type":"string"}"#)
    }

    @Test("A single-case enum is written as const")
    func singleCaseEnum() throws {
        #expect(try json(Status.openAPISchema.schema) == #"{"const":"active","type":"string"}"#)
    }

    @Test("A type with no cases is rejected")
    func noCasesTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = NoCases.openAPISchema
        }
    }

    @Test("A type's own schema replaces the enum default, including in generic code")
    func customBeatsDefault() throws {
        let expected = #"{"format":"color","type":"string"}"#
        #expect(try json(Color.openAPISchema.schema) == expected)
        #expect(try json(genericSchema(Color.self).schema) == expected)
        #expect(try json(JSONSchema.schema(for: Color.self)) == expected)
    }

    @Test("Generic code sees the enum default too")
    func genericDefault() {
        #expect(genericSchema(Role.self) == .enumeration(["user", "admin"]))
    }

    // MARK: - schema(for:)

    @Test("A provider's schema is found from its metatype")
    func schemaForProvider() throws {
        #expect(try json(JSONSchema.schema(for: Role.self)) == json(Role.openAPISchema.schema))
        #expect(try json(JSONSchema.schema(for: Money.self)) == json(Money.openAPISchema.schema))
    }

    @Test("A provider takes precedence over the builtin schema")
    func providerBeatsBuiltin() throws {
        #expect(try json(JSONSchema.schema(for: Decimal.self)) == #"{"type":"string"}"#)
        #expect(try json(JSONSchema.builtin(for: Decimal.self)) == #"{"type":"number"}"#)
    }

    @Test("Without a provider, the builtin schema is used")
    func schemaForBuiltin() throws {
        #expect(try json(JSONSchema.schema(for: String.self)) == #"{"type":"string"}"#)
        #expect(try json(JSONSchema.schema(for: UUID.self)) == #"{"format":"uuid","type":"string"}"#)
    }

    @Test("A type with neither has no schema")
    func schemaForUnknown() throws {
        #expect(JSONSchema.schema(for: User.self) == nil)
    }

    @Test("Containers of providers aren't resolved here")
    func schemaForContainers() {
        #expect(JSONSchema.schema(for: Role?.self) == nil)
        #expect(JSONSchema.schema(for: [Role].self) == nil)
        #expect(JSONSchema.schema(for: [String: Role].self) == nil)
    }
}
#endif
