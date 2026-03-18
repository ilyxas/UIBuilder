import Foundation

enum DocumentValidationError: Error, CustomStringConvertible {
    
    case missingSchema
    case unsupportedSchema(String)
    
    case tooManyNodes(Int)
    case treeTooDeep(Int)
    
    case missingEvent(String)
    case missingRequiredProp(nodeType: String, prop: String)
    case invalidPropValue(nodeType: String, prop: String, value: String, allowed: [String])
    
    var description: String {
        switch self {
        case .missingSchema:
            return "Document schema missing"
        case .unsupportedSchema(let value):
            return "Unsupported schema: \(value)"
        case .tooManyNodes(let count):
            return "Node limit exceeded: \(count)"
        case .treeTooDeep(let depth):
            return "Tree depth exceeded: \(depth)"
        case .missingEvent(let name):
            return "Event referenced but not defined: \(name)"
        case .missingRequiredProp(let nodeType, let prop):
            return "Node '\(nodeType)' is missing required prop '\(prop)'"
        case .invalidPropValue(let nodeType, let prop, let value, let allowed):
            return "Node '\(nodeType)' prop '\(prop)' has invalid value '\(value)'. Allowed: \(allowed.joined(separator: ", "))"
        }
    }
}

struct DocumentValidator {
    
    static let maxNodes = 500
    static let maxDepth = 30

    // Allowed enum values per prop
    private static let allowedKeyboardTypes     = ["default", "numberPad", "decimalPad", "email", "phone", "url"]
    private static let allowedReturnKeyTypes    = ["default", "done", "go", "search", "next"]
    private static let allowedAutocapitalization = ["none", "words", "sentences", "characters"]
    private static let allowedShapeTypes        = ["rectangle", "roundedRectangle", "circle", "capsule", "ellipse"]
    private static let allowedStrokeStyles      = ["solid", "dashed", "dotted"]
    private static let allowedGroupStyles       = ["plain", "card", "inset"]
    private static let allowedSelectionModes    = ["none", "single", "multiple"]
    
    static func validate(_ document: ScreenDocument) throws {
        
        try validateSchema(document)
        
        let stats = analyzeTree(node: document.root, depth: 1)
        
        if stats.nodeCount > maxNodes {
            throw DocumentValidationError.tooManyNodes(stats.nodeCount)
        }
        
        if stats.maxDepth > maxDepth {
            throw DocumentValidationError.treeTooDeep(stats.maxDepth)
        }
        
        try validateEvents(document)
        try validateNodes(document)
    }
    
    // MARK: - Schema
    
    private static func validateSchema(_ document: ScreenDocument) throws {
        guard !document.schema.isEmpty else {
            throw DocumentValidationError.missingSchema
        }
        if document.schema != "com.ilya.ui/1.0" {
            throw DocumentValidationError.unsupportedSchema(document.schema)
        }
    }
    
    // MARK: - Tree Analysis
    
    private static func analyzeTree(node: UINode, depth: Int) -> (nodeCount: Int, maxDepth: Int) {
        var total = 1
        var deepest = depth
        if let children = node.children {
            for child in children {
                let result = analyzeTree(node: child, depth: depth + 1)
                total += result.nodeCount
                deepest = max(deepest, result.maxDepth)
            }
        }
        return (total, deepest)
    }
    
    // MARK: - Events
    
    private static func validateEvents(_ document: ScreenDocument) throws {
        let eventNames = Set(document.events.keys)
        try walk(node: document.root) { node in
            guard let events = node.event else { return }
            for (_, name) in events {
                if !eventNames.contains(name) {
                    throw DocumentValidationError.missingEvent(name)
                }
            }
        }
    }

    // MARK: - Node prop validation

    private static func validateNodes(_ document: ScreenDocument) throws {
        try walk(node: document.root) { node in
            try validateNode(node)
        }
    }

    private static func validateNode(_ node: UINode) throws {
        let props = node.props

        switch node.type {

        case "textfield":
            // bind is required
            if props?["bind"]?.stringValue == nil {
                throw DocumentValidationError.missingRequiredProp(nodeType: "textfield", prop: "bind")
            }
            try validateEnum(props: props, node: "textfield", key: "keyboardType",
                             allowed: allowedKeyboardTypes)
            try validateEnum(props: props, node: "textfield", key: "returnKeyType",
                             allowed: allowedReturnKeyTypes)
            try validateEnum(props: props, node: "textfield", key: "autocapitalization",
                             allowed: allowedAutocapitalization)

        case "slider":
            // bind, min, max are required
            if props?["bind"]?.stringValue == nil {
                throw DocumentValidationError.missingRequiredProp(nodeType: "slider", prop: "bind")
            }
            if props?["min"]?.doubleValue == nil {
                throw DocumentValidationError.missingRequiredProp(nodeType: "slider", prop: "min")
            }
            if props?["max"]?.doubleValue == nil {
                throw DocumentValidationError.missingRequiredProp(nodeType: "slider", prop: "max")
            }

        case "shape":
            try validateEnum(props: props, node: "shape", key: "type",
                             allowed: allowedShapeTypes)
            try validateEnum(props: props, node: "shape", key: "strokeStyle",
                             allowed: allowedStrokeStyles)

        case "group":
            try validateEnum(props: props, node: "group", key: "style",
                             allowed: allowedGroupStyles)

        case "table":
            try validateEnum(props: props, node: "table", key: "selectionMode",
                             allowed: allowedSelectionModes)

        default:
            break
        }
    }

    /// Validates that a prop value, if present, is within the allowed set.
    private static func validateEnum(props: [String: DynamicValue]?, node: String,
                                     key: String, allowed: [String]) throws {
        guard let value = props?[key]?.stringValue else { return }
        if !allowed.contains(value) {
            throw DocumentValidationError.invalidPropValue(nodeType: node, prop: key,
                                                           value: value, allowed: allowed)
        }
    }
    
    // MARK: - Walk
    
    private static func walk(node: UINode, visit: (UINode) throws -> Void) rethrows {
        try visit(node)
        if let children = node.children {
            for child in children {
                try walk(node: child, visit: visit)
            }
        }
    }
}
