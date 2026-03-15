import Foundation

struct UIAction: Decodable, Sendable {
    let action: String
    let key: String?
    let value: DynamicValue?
    let min: Double?
    let max: Double?
    let screenId: String?
    let message: String?
    let title: String?
    let event: String?
    let payload: [String: DynamicValue]?
    let id: String?
    let input: [String: DynamicValue]?
    let when: Expression?

    enum CodingKeys: String, CodingKey {
        case action = "do"
        case key, value, min, max, screenId, message, title, event, payload, id, input, when
    }
}