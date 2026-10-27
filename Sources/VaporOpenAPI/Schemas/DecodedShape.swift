#if OpenAPI

struct DecodedShape {
    var type: Any.Type
    var kind: Kind
    var isNullable = false

    indirect enum Kind {
        case leaf
        case keyed([Field])
        case dictionary(DecodedShape)
        case unkeyed(DecodedShape?)
        case single(DecodedShape)
        case recursive
        case empty
    }

    struct Field {
        var name: String
        var shape: DecodedShape
        var isOptional: Bool
    }
}

#endif
