import Foundation

struct UINode: Decodable, Identifiable, Sendable {
    let id: String?
    let type: String
    let props: [String: DynamicValue]?
    let children: [UINode]?
    let host: HostDocument?
    let visibleWhen: Expression?
    let enabledWhen: Expression?
    let event: [String: String]?
    let items: [ListItem]?

    var stableId: String {
        id ?? UUID().uuidString
    }
}

// MARK: - Host

struct HostDocument: Decodable, Sendable {
    let toolbar: ToolbarHost?
}

struct ToolbarHost: Decodable, Sendable {
    let topLeading: [UINode]?
    let topTrailing: [UINode]?
    let bottomBar: [UINode]?
    let principal: [UINode]?
}

// MARK: - ListItem

struct ListItem: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let event: [String: String]?
}