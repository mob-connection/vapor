#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

private enum UserID: OpenAPILinkKey {}
private enum OrderID: OpenAPILinkKey {
    static var description: String? { "The order to look up" }
}

@Suite("OpenAPILink")
struct OpenAPILinkTests {
    // MARK: - Init

    @Test("Init stores the name and location it's given")
    func initStoresValues() {
        let link = OpenAPILink("userId", in: .request(.path))

        #expect(link.name == "userId")
        #expect(link.location == .request(.path))
    }

    // MARK: - Runtime expressions

    @Test(
        "Every location maps to the matching runtime expression",
        arguments: [
            (OpenAPILink("limit", in: .request(.query)), "$request.query.limit"),
            (OpenAPILink("X-Id", in: .request(.header)), "$request.header.X-Id"),
            (OpenAPILink("userId", in: .request(.path)), "$request.path.userId"),
            (OpenAPILink("id", in: .request(.body)), "$request.body#/id"),
            (OpenAPILink("Location", in: .response(.header)), "$response.header.Location"),
            (OpenAPILink("id", in: .response(.body)), "$response.body#/id"),
        ]
    )
    func expressions(link: OpenAPILink, expected: String) {
        #expect(link.expression?.rawValue == expected)
    }

    @Test(
        "An empty body name refers to the whole body",
        arguments: [
            (OpenAPILink.Location.request(.body), "$request.body"),
            (.response(.body), "$response.body"),
        ]
    )
    func emptyBodyNameIsWholeBody(location: OpenAPILink.Location, expected: String) {
        #expect(OpenAPILink("", in: location).expression?.rawValue == expected)
    }

    @Test(
        "A slash in a body name reaches into nested fields",
        arguments: [
            ("data/id", "$response.body#/data/id"),
            ("data/items/0/id", "$response.body#/data/items/0/id"),
            ("/id", "$response.body#/id"),
        ]
    )
    func nestedBodyFields(name: String, expected: String) {
        #expect(OpenAPILink(name, in: .response(.body)).expression?.rawValue == expected)
    }

    @Test("A tilde in a body name is escaped as a JSON pointer")
    func bodyNameTildeIsEscaped() {
        #expect(OpenAPILink("a~b", in: .response(.body)).expression?.rawValue == "$response.body#/a~0b")
    }

    @Test("Every expression round-trips through OpenAPIKit's parser")
    func expressionsParse() throws {
        let links = [
            OpenAPILink("limit", in: .request(.query)),
            OpenAPILink("X-Id", in: .request(.header)),
            OpenAPILink("userId", in: .request(.path)),
            OpenAPILink("id", in: .request(.body)),
            OpenAPILink("", in: .request(.body)),
            OpenAPILink("Location", in: .response(.header)),
            OpenAPILink("id", in: .response(.body)),
            OpenAPILink("", in: .response(.body)),
        ]
        for link in links {
            let expression = try #require(link.expression)
            #expect(OpenAPI.RuntimeExpression(rawValue: expression.rawValue) == expression)
        }
    }

    @Test("A request cookie has no runtime expression, since it can only be a target")
    func cookieHasNoExpression() {
        let link = OpenAPILink("session", in: .request(.cookie))

        #expect(link.expression == nil)
        #expect(link.location.description == "request.cookie")
        #expect(link.identifier == "RequestCookieSession")
    }

    // MARK: - Locations

    @Test(
        "Locations describe themselves as in a runtime expression",
        arguments: [
            (OpenAPILink.Location.request(.query), "request.query"),
            (.request(.header), "request.header"),
            (.request(.path), "request.path"),
            (.request(.cookie), "request.cookie"),
            (.request(.body), "request.body"),
            (.response(.header), "response.header"),
            (.response(.body), "response.body"),
        ]
    )
    func locationDescriptions(location: OpenAPILink.Location, expected: String) {
        #expect(location.description == expected)
    }

    // MARK: - Identifiers

    @Test(
        "Identifiers join the location and name in PascalCase",
        arguments: [
            (OpenAPILink("id", in: .response(.body)), "ResponseBodyId"),
            (OpenAPILink("Location", in: .response(.header)), "ResponseHeaderLocation"),
            (OpenAPILink("userId", in: .request(.path)), "RequestPathUserId"),
            (OpenAPILink("", in: .request(.body)), "RequestBody"),
        ]
    )
    func identifiers(link: OpenAPILink, expected: String) {
        #expect(link.identifier == expected)
    }

    @Test(
        "Identifiers are safe to use as component keys",
        arguments: [
            (OpenAPILink("owner name", in: .response(.body)), "ResponseBodyOwner-name"),
            (OpenAPILink("user id", in: .request(.path)), "RequestPathUser-id"),
            (OpenAPILink("X-Id", in: .request(.header)), "RequestHeaderX-Id"),
        ]
    )
    func identifiersAreComponentKeySafe(link: OpenAPILink, expected: String) throws {
        #expect(link.identifier == expected)
        let allowed = try Regex(#"^[a-zA-Z0-9\.\-_]+$"#)
        #expect(link.identifier.wholeMatch(of: allowed) != nil)
    }

    @Test("Dotted and nested body names split into PascalCase words")
    func dottedAndNestedNames() {
        #expect(OpenAPILink("owner.name", in: .response(.body)).identifier == "ResponseBodyOwnerName")
        #expect(OpenAPILink("data/id", in: .response(.body)).identifier == "ResponseBodyDataId")
    }

    // MARK: - Equality

    @Test("Links are equal only when name and location both match")
    func equality() {
        #expect(OpenAPILink("id", in: .response(.body)) == OpenAPILink("id", in: .response(.body)))
        #expect(OpenAPILink("id", in: .response(.body)) != OpenAPILink("id", in: .request(.body)))
        #expect(OpenAPILink("id", in: .response(.body)) != OpenAPILink("ID", in: .response(.body)))
    }

    // MARK: - Keys

    @Test("A key without a description defaults to nil")
    func keyDescriptionDefaultsToNil() {
        #expect(UserID.description == nil)
        #expect(OrderID.description == "The order to look up")
    }

    @Test("Key ids are equal for the same key type and differ across types")
    func keyIDs() {
        #expect(UserID.linkKeyID == UserID.linkKeyID)
        #expect(UserID.linkKeyID != OrderID.linkKeyID)
        #expect(Set([UserID.linkKeyID, UserID.linkKeyID, OrderID.linkKeyID]).count == 2)
    }
}

@Suite("Component key safety")
struct ComponentKeySafeTests {
    @Test(
        "Allowed characters are kept and everything else becomes a dash",
        arguments: [
            ("abcXYZ019", "abcXYZ019"),
            ("a.b-c_d", "a.b-c_d"),
            ("a b", "a-b"),
            ("a/b:c@d", "a-b-c-d"),
            ("ключ", "----"),
            ("", ""),
        ]
    )
    func sanitising(input: String, expected: String) {
        #expect(input.componentKeySafe == expected)
    }
}
#endif
