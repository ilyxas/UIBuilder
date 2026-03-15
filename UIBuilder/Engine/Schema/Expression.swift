import Foundation

indirect enum Expression: Decodable, Sendable {
    case bind(String)
    case eq([ExpressionValue])
    case neq([ExpressionValue])
    case gt([ExpressionValue])
    case gte([ExpressionValue])
    case lt([ExpressionValue])
    case lte([ExpressionValue])
    case and([Expression])
    case or([Expression])
    case not(Expression)
    case literal(DynamicValue)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // IMPORTANT:
        // First try expression-object syntax like:
        // { "bind": "isPro" }, { "eq": [...] }, { "and": [...] }
        if let object = try? container.decode([String: ExpressionPayload].self) {
            if let bind = object["bind"]?.stringValue {
                self = .bind(bind)
                return
            } else if let values = object["eq"]?.values {
                self = .eq(values)
                return
            } else if let values = object["neq"]?.values {
                self = .neq(values)
                return
            } else if let values = object["gt"]?.values {
                self = .gt(values)
                return
            } else if let values = object["gte"]?.values {
                self = .gte(values)
                return
            } else if let values = object["lt"]?.values {
                self = .lt(values)
                return
            } else if let values = object["lte"]?.values {
                self = .lte(values)
                return
            } else if let exprs = object["and"]?.expressions {
                self = .and(exprs)
                return
            } else if let exprs = object["or"]?.expressions {
                self = .or(exprs)
                return
            } else if let notExpr = object["not"]?.expression {
                self = .not(notExpr)
                return
            }
        }

        // Fallback: plain literal
        if let literal = try? container.decode(DynamicValue.self) {
            self = .literal(literal)
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported Expression"
        )
    }
}

enum ExpressionValue: Decodable, Sendable {
    case expression(Expression)
    case literal(DynamicValue)

    init(from decoder: Decoder) throws {
        if let expr = try? Expression(from: decoder) {
            self = .expression(expr)
        } else {
            let literal = try DynamicValue(from: decoder)
            self = .literal(literal)
        }
    }
}

struct ExpressionPayload: Decodable, Sendable {
    let stringValue: String?
    let values: [ExpressionValue]?
    let expressions: [Expression]?
    let expression: Expression?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            self.stringValue = value
            self.values = nil
            self.expressions = nil
            self.expression = nil
        } else if let value = try? container.decode([ExpressionValue].self) {
            self.stringValue = nil
            self.values = value
            self.expressions = nil
            self.expression = nil
        } else if let value = try? container.decode([Expression].self) {
            self.stringValue = nil
            self.values = nil
            self.expressions = value
            self.expression = nil
        } else if let value = try? container.decode(Expression.self) {
            self.stringValue = nil
            self.values = nil
            self.expressions = nil
            self.expression = value
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported ExpressionPayload"
            )
        }
    }
}
