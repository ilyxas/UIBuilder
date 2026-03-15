import Foundation

struct ExpressionEvaluator {
    let state: UIStateStore

    func evaluateBool(_ expr: Expression) -> Bool {
        switch expr {
        case .bind(let key):
            return state.get(key)?.boolValue ?? false

        case .literal(let value):
            return value.boolValue ?? false

        case .eq(let values):
            return compare(values, ==)

        case .neq(let values):
            return compare(values, !=)

        case .gt(let values):
            return compareNumbers(values, >)

        case .gte(let values):
            return compareNumbers(values, >=)

        case .lt(let values):
            return compareNumbers(values, <)

        case .lte(let values):
            return compareNumbers(values, <=)

        case .and(let exprs):
            return exprs.allSatisfy(evaluateBool)

        case .or(let exprs):
            return exprs.contains(where: evaluateBool)

        case .not(let expr):
            return !evaluateBool(expr)
        }
    }

    func resolveValue(_ expr: Expression) -> DynamicValue? {
        switch expr {
        case .bind(let key):
            return state.get(key)

        case .literal(let value):
            return value

        default:
            return .bool(evaluateBool(expr))
        }
    }

    private func compare(_ values: [ExpressionValue], _ op: (ComparisonValue, ComparisonValue) -> Bool) -> Bool {
        guard values.count == 2,
              let lhs = ComparisonValue(resolve(values[0])),
              let rhs = ComparisonValue(resolve(values[1])) else {
            return false
        }
        return op(lhs, rhs)
    }

    private func compareNumbers(_ values: [ExpressionValue], _ op: (Double, Double) -> Bool) -> Bool {
        guard values.count == 2,
              let lhs = resolve(values[0])?.doubleValue,
              let rhs = resolve(values[1])?.doubleValue else {
            return false
        }
        return op(lhs, rhs)
    }

    private func resolve(_ value: ExpressionValue) -> DynamicValue? {
        switch value {
        case .expression(let expr):
            return resolveValue(expr)
        case .literal(let literal):
            return literal
        }
    }
}

private enum ComparisonValue: Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)

    init?(_ value: DynamicValue?) {
        guard let value else { return nil }

        switch value {
        case .string(let v):
            self = .string(v)
        case .number(let v):
            self = .number(v)
        case .bool(let v):
            self = .bool(v)
        default:
            return nil
        }
    }
}
