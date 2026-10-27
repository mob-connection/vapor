#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The schema as compact JSON with sorted keys, so tests can compare it exactly.
private func json(_ schema: JSONSchema) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(schema), as: UTF8.self)
}

private struct User {}
struct InternalUser {}
private enum Outer {
    struct Inner {}
}
private struct Page<Item> {
    struct Cursor {
        struct Deep {}
    }
}
private struct Pair<First, Second> {}
// Non-ASCII names are valid Swift but not valid component keys.
private struct Користувач {}

/// A local type with only the module around it.
private func localType() -> Any.Type {
    struct Local {}
    return Local.self
}

/// A second `User`, kept out of the way of the one above.
private func otherUser() -> Any.Type {
    struct User {}
    return User.self
}

@Suite("Schema references")
struct SchemaReferencesTests {
    // MARK: - Component names

    @Test(
        "A component is named like the type in code, without its module",
        arguments: [
            (User.self as Any.Type, "User"),
            (InternalUser.self, "InternalUser"),
            (Outer.Inner.self, "Outer.Inner"),
            (Page<User>.self, "PageUser"),
            (Page<Outer.Inner>.self, "PageOuter.Inner"),
            (Page<[User]>.self, "PageArrayUser"),
            (Page<User?>.self, "PageOptionalUser"),
            (Page<[String: Int]>.self, "PageDictionaryStringInt"),
            (Pair<User, Int>.self, "PairUserInt"),
            (Page<User>.Cursor.self, "PageUserCursor"),
            (Page<User>.Cursor.Deep.self, "PageUserCursor.Deep"),
            (String.self, "String"),
        ]
    )
    func names(type: Any.Type, expected: String) {
        #expect(JSONSchema.componentName(for: type) == expected)
    }

    @Test("A local type is named without its unknown contexts, but keeps the types around it")
    func localTypes() {
        struct Local {}
        #expect(JSONSchema.componentName(for: localType()) == "Local")
        #expect(JSONSchema.componentName(for: Local.self) == "SchemaReferencesTests.Local")
        #expect(JSONSchema.componentName(for: Page<Local>.self) == "PageSchemaReferencesTests.Local")
    }

    @Test("Characters that aren't allowed in a component key are replaced")
    func unsafeCharacters() {
        let name = JSONSchema.componentName(for: Користувач.self)
        #expect(name == String(repeating: "-", count: "Користувач".count))
    }

    @Test("Types with the same name share a component name, so callers have to tell them apart")
    func sameName() {
        #expect(JSONSchema.componentName(for: User.self) == "User")
        #expect(JSONSchema.componentName(for: otherUser()) == "User")
    }

    // MARK: - Referenceable

    @Test(
        "Named shapes are stored as components",
        arguments: [
            OpenAPISchema.object(["id": .integer()]),
            .object(),
            .enumeration(["admin", "user"]),
            .enumeration(["admin"]),
            .enumeration(["admin"]).nullable(),
        ]
    )
    func referenceable(schema: OpenAPISchema) {
        #expect(schema.schema.isReferenceable)
    }

    @Test(
        "Primitives, arrays and dictionaries stay inline",
        arguments: [
            OpenAPISchema.string(),
            .string(format: .uuid),
            .integer(),
            .number(),
            .boolean,
            .array(of: .object(["id": .integer()])),
            .dictionary(of: .string()),
        ]
    )
    func inline(schema: OpenAPISchema) {
        #expect(!schema.schema.isReferenceable)
    }

    @Test("Compositions are stored as components")
    func compositions() {
        #expect(JSONSchema.all(of: [.string, .integer]).isReferenceable)
        #expect(JSONSchema.one(of: [.string, .integer]).isReferenceable)
        #expect(JSONSchema.any(of: [.string, .integer]).isReferenceable)
        #expect(JSONSchema.not(.string).isReferenceable)
    }

    @Test("An object that forbids extra properties is a named shape, one that allows any isn't")
    func additionalPropertiesFlag() {
        #expect(JSONSchema.object(additionalProperties: .a(false)).isReferenceable)
        #expect(!JSONSchema.object(additionalProperties: .a(true)).isReferenceable)
    }

    @Test("A reference is already a reference")
    func referenceIsntReferenceable() {
        #expect(!JSONSchema.reference(.component(named: "User")).isReferenceable)
    }

    // MARK: - Allowing null

    @Test("A reference allows null through anyOf, since it can't take a type")
    func nullableReference() throws {
        let schema = JSONSchema.reference(.component(named: "User")).allowingNull()
        #expect(try json(schema) == ##"{"anyOf":[{"$ref":"#/components/schemas/User"},{"type":"null"}]}"##)
    }

    @Test("A nullable reference keeps its description and stays optional in an object")
    func nullableReferenceKeepsCore() throws {
        let reference = JSONSchema.reference(.component(named: "User"), required: false, description: "The manager")
        let schema = reference.allowingNull()
        #expect(!schema.required)
        #expect(
            try json(schema)
                == ##"{"anyOf":[{"$ref":"#/components/schemas/User"},{"type":"null"}],"description":"The manager"}"##
        )
    }

    @Test("Other schemas add null to their type, and to their enum")
    func nullableValues() throws {
        #expect(try json(JSONSchema.string.allowingNull()) == #"{"type":["string","null"]}"#)
        #expect(
            try json(JSONSchema.string(allowedValues: "admin", "user").allowingNull())
                == #"{"enum":["admin","user",null],"type":["string","null"]}"#
        )
    }

    @Test("Allowing null twice is the same as once")
    func nullableIsIdempotent() throws {
        let reference = JSONSchema.reference(.component(named: "User"))
        let composition = JSONSchema.one(of: [.string, .integer])
        for schema in [JSONSchema.string, reference, composition] {
            #expect(try json(schema.allowingNull().allowingNull()) == json(schema.allowingNull()))
        }
    }

    @Test("A composition allows null through anyOf, since a type next to it would only allow null")
    func nullableComposition() throws {
        let schema = JSONSchema.one(of: .string, .integer, required: false).allowingNull()
        #expect(!schema.required)
        #expect(
            try json(schema)
                == #"{"anyOf":[{"oneOf":[{"type":"string"},{"type":"integer"}]},{"type":"null"}]}"#
        )
    }
}
#endif
