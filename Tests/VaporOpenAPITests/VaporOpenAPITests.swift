#if OpenAPI
import OpenAPIKit
import Testing
@testable import VaporOpenAPI

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("OpenAPIAuth")
struct OpenAPIAuthTests {
    static let authorizationURL = URL(string: "https://example.com/oauth/authorize")!
    static let tokenURL = URL(string: "https://example.com/oauth/token")!
    static let refreshURL = URL(string: "https://example.com/oauth/refresh")!
    static let openIDURL = URL(string: "https://example.com/.well-known/openid-configuration")!

    // MARK: - Init

    @Test("Basic and bearer get different auto ids")
    func basicAndBearerDiffer() {
        #expect(OpenAPIAuth.basic().id != OpenAPIAuth.bearer().id)
    }

    @Test("Init stores the id, scopes and scheme it's given")
    func initStoresValues() {
        let scheme = OpenAPI.SecurityScheme.http(scheme: "basic", description: "Basic authentication")
        let auth = OpenAPIAuth(id: "basic", scopes: ["read", "write"], scheme: scheme)

        #expect(auth.id == "basic")
        #expect(auth.scopes == ["read", "write"])
        #expect(auth.scheme == scheme)
    }

    @Test("Init falls back to the scheme's auto name when no id is given")
    func initUsesAutoNameWithoutID() {
        let scheme = OpenAPI.SecurityScheme.http(scheme: "bearer", bearerFormat: "JWT")
        let auth = OpenAPIAuth(id: nil, scheme: scheme)

        #expect(auth.id == "http_bearer_JWT")
        #expect(auth.scopes.isEmpty)
    }

    @Test("An explicit id wins over the auto name, even an empty one")
    func explicitIDWins() {
        #expect(OpenAPIAuth.basic(id: "custom").id == "custom")
        #expect(OpenAPIAuth.bearer(id: "").id == "")
    }

    // MARK: - Scopes

    @Test("Variadic and array scopes produce the same result")
    func scopesVariadicAndArray() {
        let auth = OpenAPIAuth.bearer(format: "JWT")

        #expect(auth.scopes("read", "write").scopes == ["read", "write"])
        #expect(auth.scopes(["read", "write"]).scopes == ["read", "write"])
    }

    @Test("Setting scopes returns a copy and leaves the original untouched")
    func scopesReturnCopy() {
        let original = OpenAPIAuth.bearer()
        let scoped = original.scopes("read")

        #expect(original.scopes.isEmpty)
        #expect(scoped.scopes == ["read"])
        #expect(scoped.id == original.id)
        #expect(scoped.scheme == original.scheme)
    }

    @Test("Setting scopes replaces the previous ones instead of appending")
    func scopesReplace() {
        let auth = OpenAPIAuth.bearer().scopes("read").scopes("write")
        #expect(auth.scopes == ["write"])
    }

    @Test("Setting no scopes clears them")
    func scopesClear() {
        let auth = OpenAPIAuth.bearer().scopes("read").scopes()
        #expect(auth.scopes.isEmpty)
    }

    @Test("Scopes keep their order and duplicates as given")
    func scopesKeepOrderAndDuplicates() {
        let auth = OpenAPIAuth.bearer().scopes("write", "read", "write")
        #expect(auth.scopes == ["write", "read", "write"])
    }

    // MARK: - HTTP schemes

    @Test("Basic builds an HTTP basic scheme")
    func basic() {
        let auth = OpenAPIAuth.basic(description: "Basic authentication")

        #expect(auth.id == "http_basic")
        #expect(auth.scheme.type == .http(scheme: "basic", bearerFormat: nil))
        #expect(auth.scheme.description == "Basic authentication")
        #expect(auth.scheme.deprecated == false)
    }

    @Test("Bearer builds an HTTP bearer scheme with an optional format")
    func bearer() {
        #expect(OpenAPIAuth.bearer().id == "http_bearer")
        #expect(OpenAPIAuth.bearer().scheme.type == .http(scheme: "bearer", bearerFormat: nil))

        let jwt = OpenAPIAuth.bearer(format: "JWT")
        #expect(jwt.id == "http_bearer_JWT")
        #expect(jwt.scheme.type == .http(scheme: "bearer", bearerFormat: "JWT"))
    }

    @Test("An empty bearer format is left out of the auto id")
    func bearerEmptyFormat() {
        #expect(OpenAPIAuth.bearer(format: "").id == "http_bearer")
    }

    // MARK: - API key

    @Test("API key defaults to the header location")
    func apiKeyDefaultsToHeader() {
        let auth = OpenAPIAuth.apiKey(name: "X-API-Key")

        #expect(auth.id == "apiKey_header_X-API-Key")
        #expect(auth.scheme.type == .apiKey(name: "X-API-Key", location: .header))
    }

    @Test(
        "API key maps every location",
        arguments: [
            (OpenAPIAuth.SecurityLocation.query, OpenAPI.SecurityScheme.Location.query, "apiKey_query_token"),
            (.header, .header, "apiKey_header_token"),
            (.cookie, .cookie, "apiKey_cookie_token"),
        ]
    )
    func apiKeyLocations(
        location: OpenAPIAuth.SecurityLocation,
        expected: OpenAPI.SecurityScheme.Location,
        id: String
    ) {
        let auth = OpenAPIAuth.apiKey(name: "token", in: location)

        #expect(location.location == expected)
        #expect(auth.id == id)
        #expect(auth.scheme.type == .apiKey(name: "token", location: expected))
    }

    @Test("API keys with different names in the same location get different auto ids")
    func apiKeyNamesDontCollide() {
        let tenant = OpenAPIAuth.apiKey(name: "X-Tenant-Key")
        let api = OpenAPIAuth.apiKey(name: "X-API-Key")

        #expect(tenant.id == "apiKey_header_X-Tenant-Key")
        #expect(tenant.id != api.id)
    }

    // MARK: - Component key safety

    @Test(
        "Characters not allowed in component keys are replaced with a dash",
        arguments: [
            (OpenAPIAuth.bearer(format: "JWT token"), "http_bearer_JWT-token"),
            (OpenAPIAuth.apiKey(name: "X Api Key"), "apiKey_header_X-Api-Key"),
            (OpenAPIAuth.apiKey(name: "key/with:odd@chars"), "apiKey_header_key-with-odd-chars"),
            (OpenAPIAuth.apiKey(name: "ключ"), "apiKey_header_----"),
            (OpenAPIAuth.apiKey(name: "api.key_v2-final"), "apiKey_header_api.key_v2-final"),
        ]
    )
    func autoIDIsComponentKeySafe(auth: OpenAPIAuth, id: String) throws {
        #expect(auth.id == id)
        let allowed = try Regex(#"^[a-zA-Z0-9\.\-_]+$"#)
        #expect(auth.id.wholeMatch(of: allowed) != nil)
    }

    @Test("The scheme itself keeps the original, unsanitised values")
    func sanitisingOnlyAffectsTheID() {
        let auth = OpenAPIAuth.apiKey(name: "X Api Key")
        #expect(auth.scheme.type == .apiKey(name: "X Api Key", location: .header))
    }

    @Test("An explicit id is used as given, without sanitising")
    func explicitIDIsNotSanitised() {
        #expect(OpenAPIAuth.basic(id: "my auth").id == "my auth")
    }

    // MARK: - OpenID Connect & mutual TLS

    @Test("OpenID Connect keeps its discovery URL")
    func openIDConnect() {
        let auth = OpenAPIAuth.openIDConnect(url: Self.openIDURL)

        #expect(auth.id == "openIdConnect")
        #expect(auth.scheme.type == .openIdConnect(openIdConnectUrl: Self.openIDURL))
    }

    @Test("Mutual TLS builds a mutualTLS scheme")
    func mutualTLS() {
        let auth = OpenAPIAuth.mutualTLS()

        #expect(auth.id == "mutualTLS")
        #expect(auth.scheme.type == .mutualTLS)
    }

    // MARK: - OAuth2

    @Test("Implicit flow keeps its URLs and scopes, and no other flow is set")
    func oauth2Implicit() throws {
        let auth = OpenAPIAuth.oauth2(
            flows: .implicit(
                authorizationUrl: Self.authorizationURL,
                refreshUrl: Self.refreshURL,
                scopes: ["read:pets": "Read your pets"]
            )
        )
        let flows = try #require(oauth2Flows(auth))

        #expect(auth.id == "oauth2_implicit")
        let implicit = try #require(flows.implicit)
        #expect(implicit.authorizationUrl == Self.authorizationURL)
        #expect(implicit.refreshUrl == Self.refreshURL)
        #expect(implicit.scopes == ["read:pets": "Read your pets"])
        #expect(flows.password == nil)
        #expect(flows.clientCredentials == nil)
        #expect(flows.authorizationCode == nil)
        #expect(flows.deviceAuthorization == nil)
    }

    @Test("Password flow keeps its token URL")
    func oauth2Password() throws {
        let auth = OpenAPIAuth.oauth2(flows: .password(tokenUrl: Self.tokenURL))
        let password = try #require(oauth2Flows(auth)?.password)

        #expect(auth.id == "oauth2_password")
        #expect(password.tokenUrl == Self.tokenURL)
        #expect(password.refreshUrl == nil)
        #expect(password.scopes.isEmpty)
    }

    @Test("Client credentials flow keeps its token URL")
    func oauth2ClientCredentials() throws {
        let auth = OpenAPIAuth.oauth2(flows: .clientCredentials(tokenUrl: Self.tokenURL))
        let clientCredentials = try #require(oauth2Flows(auth)?.clientCredentials)

        #expect(auth.id == "oauth2_clientCredentials")
        #expect(clientCredentials.tokenUrl == Self.tokenURL)
    }

    @Test("Authorization code flow keeps both of its URLs")
    func oauth2AuthorizationCode() throws {
        let auth = OpenAPIAuth.oauth2(
            flows: .authorizationCode(authorizationUrl: Self.authorizationURL, tokenUrl: Self.tokenURL)
        )
        let authorizationCode = try #require(oauth2Flows(auth)?.authorizationCode)

        #expect(auth.id == "oauth2_authorizationCode")
        #expect(authorizationCode.authorizationUrl == Self.authorizationURL)
        #expect(authorizationCode.tokenUrl == Self.tokenURL)
    }

    @Test("Device authorization flow keeps both of its URLs")
    func oauth2DeviceAuthorization() throws {
        let auth = OpenAPIAuth.oauth2(
            flows: .deviceAuthorization(deviceAuthorizationUrl: Self.authorizationURL, tokenUrl: Self.tokenURL)
        )
        let deviceAuthorization = try #require(oauth2Flows(auth)?.deviceAuthorization)

        #expect(auth.id == "oauth2_deviceAuthorization")
        #expect(deviceAuthorization.deviceAuthorizationUrl == Self.authorizationURL)
        #expect(deviceAuthorization.tokenUrl == Self.tokenURL)
    }

    @Test("OAuth2 passes the metadata URL and description through")
    func oauth2MetadataAndDescription() {
        let auth = OpenAPIAuth.oauth2(
            flows: .password(tokenUrl: Self.tokenURL),
            metadataUrl: Self.openIDURL,
            description: "Pet store OAuth"
        )

        #expect(auth.scheme.type.oauth2MetadataUrl == Self.openIDURL)
        #expect(auth.scheme.description == "Pet store OAuth")
    }

    @Test("OAuth2 scopes come out sorted by name")
    func oauth2ScopesSorted() throws {
        let auth = OpenAPIAuth.oauth2(
            flows: .clientCredentials(
                tokenUrl: Self.tokenURL,
                scopes: ["write:pets": "Modify", "admin": "Everything", "read:pets": "Read"]
            )
        )
        let scopes = try #require(oauth2Flows(auth)?.clientCredentials?.scopes)

        #expect(Array(scopes.keys) == ["admin", "read:pets", "write:pets"])
        #expect(scopes["admin"] == "Everything")
    }

    // MARK: - Descriptions & equality

    @Test("Descriptions are optional for every scheme")
    func descriptionsDefaultToNil() {
        let auths: [OpenAPIAuth] = [
            .basic(),
            .bearer(),
            .apiKey(name: "X-API-Key"),
            .openIDConnect(url: Self.openIDURL),
            .oauth2(flows: .password(tokenUrl: Self.tokenURL)),
            .mutualTLS(),
        ]
        for auth in auths {
            #expect(auth.scheme.description == nil)
        }
    }

    @Test("Two auths built the same way are equal")
    func equalWhenBuiltTheSameWay() {
        #expect(OpenAPIAuth.bearer(format: "JWT") == OpenAPIAuth.bearer(format: "JWT"))
        #expect(OpenAPIAuth.bearer().scopes("read") == OpenAPIAuth.bearer().scopes("read"))
    }

    @Test("Auths differ when their scopes, description or id differ")
    func notEqualWhenAnythingDiffers() {
        #expect(OpenAPIAuth.bearer().scopes("read") != OpenAPIAuth.bearer().scopes("write"))
        #expect(OpenAPIAuth.bearer(description: "a") != OpenAPIAuth.bearer(description: "b"))
        #expect(OpenAPIAuth.bearer(id: "a") != OpenAPIAuth.bearer(id: "b"))
    }

    @Test("Every kind of scheme gets a distinct auto id")
    func autoIDsAreDistinct() {
        let ids = [
            OpenAPIAuth.basic(),
            .bearer(),
            .bearer(format: "JWT"),
            .apiKey(name: "key", in: .query),
            .apiKey(name: "key", in: .header),
            .apiKey(name: "key", in: .cookie),
            .openIDConnect(url: Self.openIDURL),
            .oauth2(flows: .implicit(authorizationUrl: Self.authorizationURL)),
            .oauth2(flows: .password(tokenUrl: Self.tokenURL)),
            .oauth2(flows: .clientCredentials(tokenUrl: Self.tokenURL)),
            .oauth2(flows: .authorizationCode(authorizationUrl: Self.authorizationURL, tokenUrl: Self.tokenURL)),
            .oauth2(flows: .deviceAuthorization(deviceAuthorizationUrl: Self.authorizationURL, tokenUrl: Self.tokenURL)),
            .mutualTLS(),
        ].map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    // MARK: - Encoding

    @Test("Basic encodes to the OpenAPI security scheme shape")
    func basicEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(OpenAPIAuth.basic().scheme), as: UTF8.self)

        #expect(json == #"{"scheme":"basic","type":"http"}"#)
    }

    @Test("API key encodes its name and location")
    func apiKeyEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(OpenAPIAuth.apiKey(name: "X-API-Key", in: .query).scheme), as: UTF8.self)

        #expect(json == #"{"in":"query","name":"X-API-Key","type":"apiKey"}"#)
    }

    // MARK: - Helpers

    private func oauth2Flows(_ auth: OpenAPIAuth) -> OpenAPI.OAuthFlows? {
        guard case .oauth2(let flows, _) = auth.scheme.type else { return nil }
        return flows
    }
}

@Suite("Sorted OrderedDictionary")
struct SortedOrderedDictionaryTests {
    @Test("An empty dictionary stays empty")
    func empty() {
        #expect([String: String]().sortedOrderedDictionary.isEmpty)
    }

    @Test("Keys come out sorted and values stay with their keys")
    func sortedKeysKeepValues() {
        let ordered = ["b": "2", "c": "3", "a": "1"].sortedOrderedDictionary

        #expect(Array(ordered.keys) == ["a", "b", "c"])
        #expect(Array(ordered.values) == ["1", "2", "3"])
    }

    @Test("Sorting is by Unicode order, so uppercase comes before lowercase")
    func uppercaseBeforeLowercase() {
        let ordered = ["a": "", "B": "", "_": ""].sortedOrderedDictionary
        #expect(Array(ordered.keys) == ["B", "_", "a"])
    }
}
#endif
