//
//  LayoutSupport.swift
//  UIBuilder
//
//  Created by ilya on 08/03/2026.
//

import SwiftUI

struct LayoutItemMetrics {
    let width: CGFloat?
    let flex: Double?
}

enum LayoutSupport {
    static func metrics(for props: [String: DynamicValue]?) -> LayoutItemMetrics {
        LayoutItemMetrics(
            width: props?["width"]?.doubleValue.map { CGFloat($0) },
            flex: props?["flex"]?.doubleValue
        )
    }
}
