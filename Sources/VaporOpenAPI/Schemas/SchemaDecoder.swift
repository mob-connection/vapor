#if OpenAPI

final class SchemaDecoder {
    let path: [Any.Type]
    let codingPath: [any CodingKey]
    var kind: DecodedShape.Kind = .empty
    var isNullable = false

    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    init(
        path: [Any.Type],
        codingPath: [any CodingKey]
    ) {
        self.path = path
        self.codingPath = codingPath
    }

    static func shape<T: Decodable>(of type: T.Type) throws -> DecodedShape {
        try SchemaDecoder(path: [], codingPath: []).decodeNested(type).shape
    }

    func decodeNested<T: Decodable>(_ type: T.Type) throws -> (value: T, shape: DecodedShape) {
        if let placeholder = Placeholder.value(for: type) {
            return (placeholder, DecodedShape(type: type, kind: .leaf))
        }
        let child = SchemaDecoder(path: path + [type], codingPath: codingPath)
        let value = try T(from: child)
        let decodedShape = DecodedShape(type: type, kind: child.kind, isNullable: child.isNullable)
        return (value, decodedShape)
    }

    func append(_ field: DecodedShape.Field) {
        guard case .keyed(var fields) = kind else { return }
        fields.append(field)
        kind = .keyed(fields)
    }
}

extension SchemaDecoder: Decoder {
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        kind = .keyed([])
        let keyedContainer = KeyedContainer<Key>(decoder: self)
        let keyedDecodingContainer = KeyedDecodingContainer(keyedContainer)
        return keyedDecodingContainer
    }

    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        kind = .unkeyed(nil)
        let unkeyedContainer = UnkeyedContainer(decoder: self)
        return unkeyedContainer
    }

    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        SingleContainer(decoder: self)
    }
}

extension SchemaDecoder {
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: SchemaDecoder
        var codingPath: [any CodingKey] { decoder.codingPath }
        var allKeys: [Key] { [] }

        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            try decodeField(type, forKey: key, isOptional: false)
        }

        func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decode(_ type: Int128.Type, forKey key: Key) throws -> Int128 {
            try decodeField(type, forKey: key, isOptional: false)
        }

        func decode(_ type: UInt128.Type, forKey key: Key) throws -> UInt128 {
            try decodeField(type, forKey: key, isOptional: false)
        }

        func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: Int128.Type, forKey key: Key) throws -> Int128? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func decodeIfPresent(_ type: UInt128.Type, forKey key: Key) throws -> UInt128? {
            try decodeField(type, forKey: key, isOptional: true)
        }

        func contains(_ key: Key) -> Bool {
            true
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            false
        }

        func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<
            NestedKey
        > {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [key], debugDescription: "Nested containers aren't supported yet")
            )
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [key], debugDescription: "Nested unkeyed containers aren't supported yet")
            )
        }

        func superDecoder() throws -> any Decoder {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Super decoders aren't supported yet")
            )
        }

        func superDecoder(forKey key: Key) throws -> any Decoder {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath + [key], debugDescription: "Super decoders aren't supported yet")
            )
        }

        private func decodeField<T: Decodable>(_ type: T.Type, forKey key: Key, isOptional: Bool) throws -> T {
            let fieldDecoder = SchemaDecoder(path: decoder.path, codingPath: decoder.codingPath + [key])
            let (value, shape) = try fieldDecoder.decodeNested(type)
            decoder.append(DecodedShape.Field(name: key.stringValue, shape: shape, isOptional: isOptional))
            return value
        }
    }
}

extension SchemaDecoder {
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        let decoder: SchemaDecoder
        var currentIndex: Int = 0
        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        var count: Int? {
            nil
        }

        var isAtEnd: Bool {
            currentIndex > 0
        }

        mutating func decodeNil() throws -> Bool {
            false
        }

        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try decodeElement(type)
        }

        mutating func decode(_ type: Int128.Type) throws -> Int128 {
            try decodeElement(type)
        }

        mutating func decode(_ type: UInt128.Type) throws -> UInt128 {
            try decodeElement(type)
        }

        mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Nested containers aren't supported yet")
            )
        }

        mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Nested unkeyed containers aren't supported yet")
            )
        }

        mutating func superDecoder() throws -> any Decoder {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "Super decoders aren't supported yet")
            )
        }

        private mutating func decodeElement<T: Decodable>(_ type: T.Type) throws -> T {
            let elementDecoder = SchemaDecoder(path: decoder.path, codingPath: decoder.codingPath)
            let (value, shape) = try elementDecoder.decodeNested(type)
            decoder.kind = .unkeyed(shape)
            currentIndex += 1
            return value
        }
    }
}

extension SchemaDecoder {
    struct SingleContainer: SingleValueDecodingContainer {
        let decoder: SchemaDecoder

        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        func decodeNil() -> Bool {
            decoder.isNullable = true
            return false
        }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try decodeValue(type)
        }

        func decode(_ type: Int128.Type) throws -> Int128 {
            try decodeValue(type)
        }

        func decode(_ type: UInt128.Type) throws -> UInt128 {
            try decodeValue(type)
        }

        private func decodeValue<T: Decodable>(_ type: T.Type) throws -> T {
            let decoder = SchemaDecoder(path: decoder.path, codingPath: decoder.codingPath)
            let (value, shape) = try decoder.decodeNested(type)
            self.decoder.kind = .single(shape)
            return value
        }
    }
}

#endif
