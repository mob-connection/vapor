#if OpenAPI
import Testing
@testable import VaporOpenAPI

private struct User: Codable, Sendable {
    var id: Int
    var name: String
}

private struct Admin: Codable, Sendable {
    var id: Int
    var permissions: [String]
}

private struct Paging: Codable, Sendable {
    var page: Int
    var per: Int
}

private struct Filter: Codable, Sendable {
    var query: String?
}

/// A non-`Sendable` model: only its metatype is stored, so it can still be described by type.
private final class Model: Decodable {
    var id = 0
}

/// A readable description of a value's structure, so tests can compare it without `Equatable`.
private func shape(_ value: OpenAPIValue) -> String {
    switch value {
    case .type(let type): "type(\(type))"
    case .example(let example): "example(\(Swift.type(of: example)))"
    case .allOf(let values): "allOf[\(values.map(shape).joined(separator: ", "))]"
    case .anyOf(let values): "anyOf[\(values.map(shape).joined(separator: ", "))]"
    case .oneOf(let values): "oneOf[\(values.map(shape).joined(separator: ", "))]"
    case .not(let value): "not(\(shape(value)))"
    }
}

/// The exact type stored by a `.type` value, compared by identity rather than by name.
private func storedType(_ value: OpenAPIValue) -> ObjectIdentifier? {
    guard case .type(let type) = value else { return nil }
    return ObjectIdentifier(type)
}

@Suite("OpenAPIBody")
struct OpenAPIBodyTests {
    @Test("A type is stored as exactly that type")
    func type() {
        let body = OpenAPIBody.type(User.self)

        #expect(shape(body.value) == "type(User)")
        #expect(storedType(body.value) == ObjectIdentifier(User.self))
    }

    @Test("A non-Sendable type can be described, since only its metatype is stored")
    func nonSendableType() {
        #expect(storedType(OpenAPIBody.type(Model.self).value) == ObjectIdentifier(Model.self))
    }

    @Test("An example is stored as the value it's given")
    func example() throws {
        let body = OpenAPIBody.example(User(id: 1, name: "Ada"))
        #expect(shape(body.value) == "example(User)")

        guard case .example(let stored) = body.value else {
            Issue.record("Expected an example")
            return
        }
        let user = try #require(stored as? User)
        #expect(user.id == 1)
        #expect(user.name == "Ada")
    }

    @Test(
        "Each composition maps to its own case",
        arguments: [
            (OpenAPIBody.all(of: .type(User.self), .type(Admin.self)), "allOf[type(User), type(Admin)]"),
            (OpenAPIBody.any(of: .type(User.self), .type(Admin.self)), "anyOf[type(User), type(Admin)]"),
            (OpenAPIBody.one(of: .type(User.self), .type(Admin.self)), "oneOf[type(User), type(Admin)]"),
            (OpenAPIBody.not(.type(User.self)), "not(type(User))"),
        ]
    )
    func compositions(body: OpenAPIBody, expected: String) {
        #expect(shape(body.value) == expected)
    }

    @Test(
        "The array and variadic forms of a composition are the same",
        arguments: [
            (OpenAPIBody.all(of: [.type(User.self), .type(Admin.self)]), "allOf[type(User), type(Admin)]"),
            (OpenAPIBody.any(of: [.type(User.self), .type(Admin.self)]), "anyOf[type(User), type(Admin)]"),
            (OpenAPIBody.one(of: [.type(User.self), .type(Admin.self)]), "oneOf[type(User), type(Admin)]"),
        ]
    )
    func arrayCompositions(body: OpenAPIBody, expected: String) {
        #expect(shape(body.value) == expected)
    }

    @Test("A composition can be built from an array made at runtime")
    func runtimeArray() {
        let variants: [OpenAPIBody] = [User.self, Admin.self].map { type in
            type == User.self ? .type(User.self) : .type(Admin.self)
        }
        #expect(shape(OpenAPIBody.one(of: variants).value) == "oneOf[type(User), type(Admin)]")
    }

    @Test("Compositions keep the order they're given in")
    func compositionOrder() {
        let body = OpenAPIBody.one(of: .type(Admin.self), .type(User.self))
        #expect(shape(body.value) == "oneOf[type(Admin), type(User)]")
    }

    @Test("Types and examples can be mixed in a composition")
    func mixedComposition() {
        let body = OpenAPIBody.one(of: .type(User.self), .example(Admin(id: 1, permissions: [])))
        #expect(shape(body.value) == "oneOf[type(User), example(Admin)]")
    }

    @Test("Compositions nest and aren't flattened")
    func nestedCompositions() {
        let body = OpenAPIBody.all(of: .type(User.self), .all(of: .type(Admin.self), .not(.type(Paging.self))))
        #expect(shape(body.value) == "allOf[type(User), allOf[type(Admin), not(type(Paging))]]")
    }

    @Test("A single-item composition is still a composition")
    func singleItemComposition() {
        #expect(shape(OpenAPIBody.one(of: .type(User.self)).value) == "oneOf[type(User)]")
    }

    @Test("Double negation is kept as written")
    func doubleNegation() {
        #expect(shape(OpenAPIBody.not(.not(.type(User.self))).value) == "not(not(type(User)))")
    }

    @Test("An empty all of is rejected")
    func emptyAllTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = OpenAPIBody.all(of: [OpenAPIBody]())
        }
    }

    @Test("An empty any of is rejected")
    func emptyAnyTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = OpenAPIBody.any(of: [OpenAPIBody]())
        }
    }

    @Test("An empty one of is rejected")
    func emptyOneTraps() async {
        await #expect(processExitsWith: .failure) {
            _ = OpenAPIBody.one(of: [OpenAPIBody]())
        }
    }
}

@Suite("OpenAPIParameters")
struct OpenAPIParametersTests {
    @Test("A type is stored as exactly that type")
    func type() {
        let parameters = OpenAPIParameters.type(Paging.self)

        #expect(shape(parameters.value) == "type(Paging)")
        #expect(storedType(parameters.value) == ObjectIdentifier(Paging.self))
    }

    @Test("An example is stored as the value it's given")
    func example() throws {
        let parameters = OpenAPIParameters.example(Paging(page: 2, per: 25))
        #expect(shape(parameters.value) == "example(Paging)")

        guard case .example(let stored) = parameters.value else {
            Issue.record("Expected an example")
            return
        }
        let paging = try #require(stored as? Paging)
        #expect(paging.page == 2)
        #expect(paging.per == 25)
    }

    @Test("All of combines parameters in order")
    func allOf() {
        let parameters = OpenAPIParameters.all(of: .type(Paging.self), .type(Filter.self))
        #expect(shape(parameters.value) == "allOf[type(Paging), type(Filter)]")
    }

    @Test("An array literal combines parameters like all of")
    func arrayLiteral() {
        let parameters: OpenAPIParameters = [.type(Paging.self), .example(Filter(query: "ada"))]
        #expect(shape(parameters.value) == "allOf[type(Paging), example(Filter)]")
    }

    @Test("The variadic, array and literal forms produce the same result")
    func formsMatch() {
        let variadic = OpenAPIParameters.all(of: .type(Paging.self), .type(Filter.self))
        let array = OpenAPIParameters.all(of: [.type(Paging.self), .type(Filter.self)])
        let literal: OpenAPIParameters = [.type(Paging.self), .type(Filter.self)]

        #expect(shape(variadic.value) == shape(array.value))
        #expect(shape(variadic.value) == shape(literal.value))
    }

    @Test("Nested combinations are flattened into one list")
    func flattening() {
        let paging: OpenAPIParameters = [.type(Paging.self)]
        let parameters: OpenAPIParameters = [paging, .all(of: [.type(Filter.self)]), .type(User.self)]
        #expect(shape(parameters.value) == "allOf[type(Paging), type(Filter), type(User)]")
    }

    @Test("Deeply nested combinations are flattened into one list")
    func deepFlattening() {
        let parameters = OpenAPIParameters.all(of: .all(of: .all(of: .type(Paging.self))), .type(Filter.self))
        #expect(shape(parameters.value) == "allOf[type(Paging), type(Filter)]")
    }

    @Test("An empty list of parameters is allowed")
    func emptyParameters() {
        let parameters: OpenAPIParameters = []
        #expect(shape(parameters.value) == "allOf[]")
        #expect(shape(OpenAPIParameters.all(of: [OpenAPIParameters]()).value) == "allOf[]")
    }
}
#endif
