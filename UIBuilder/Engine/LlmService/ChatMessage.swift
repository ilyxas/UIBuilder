//
//  ChatMessage.swift
//  UIBuilder
//
//  Created by ilya on 26/03/2026.
//

import Foundation

struct ChatMessage: Identifiable, Hashable {
    enum Role: String {
        case user
        case assistant
        case system
    }

    let id = UUID()
    let role: Role
    let text: String
    let createdAt: Date = Date()
}

