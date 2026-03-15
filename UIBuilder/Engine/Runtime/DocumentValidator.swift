import Foundation

enum DocumentValidationError: Error, CustomStringConvertible {
    
    case missingSchema
    case unsupportedSchema(String)
    
    case tooManyNodes(Int)
    case treeTooDeep(Int)
    
    case missingEvent(String)
    
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
        }
    }
}

struct DocumentValidator {
    
    static let maxNodes = 500
    static let maxDepth = 30
    
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