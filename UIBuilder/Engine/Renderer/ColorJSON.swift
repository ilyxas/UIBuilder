//
//  ColorJSON.swift
//  UIBuilder
//
//  Created by ilya on 07/03/2026.
//

import SwiftUI

extension Color {

    init(hex: String) {
        var hex = hex

        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        let rgb = UInt64(hex, radix: 16) ?? 0

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
    
    static func fromDynamic(_ value: DynamicValue?) -> Color? {

        
        guard let hexValue = value?.stringValue else { return nil }

        var hex = hexValue

        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard let rgb = UInt64(hex, radix: 16) else { return nil }

        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
