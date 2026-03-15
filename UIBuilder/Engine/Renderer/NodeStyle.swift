//
//  NodeStyle.swift
//  UIBuilder
//
//  Created by ilya on 07/03/2026.
//

import SwiftUI

struct NodeStyle {

    static func apply<V: View>(_ view: V, props: [String: DynamicValue]?) -> AnyView {

        var v = AnyView(view)

        guard let props else { return v }
        
        

        // padding
        if let padding = props["padding"]?.doubleValue {
            v = AnyView(v.padding(CGFloat(padding)))
        }

        // width / height
        let width: CGFloat? = props["width"]?.doubleValue.map { CGFloat($0) }
        let height: CGFloat? = props["height"]?.doubleValue.map { CGFloat($0) }

        if width != nil || height != nil {
            v = AnyView(
                v.frame(
                    width: width,
                    height: height
                )
            )
        }

        // minWidth / minHeight
        let minWidth: CGFloat? = props["minWidth"]?.doubleValue.map { CGFloat($0) }
        let minHeight: CGFloat? = props["minHeight"]?.doubleValue.map { CGFloat($0) }

        if minWidth != nil || minHeight != nil {
            v = AnyView(
                v.frame(
                    minWidth: minWidth,
                    minHeight: minHeight
                )
            )
        }

        // maxWidth / maxHeight
        let maxWidth: CGFloat? = (props["maxWidth"]?.stringValue == "infinity")
            ? CGFloat.infinity
            : props["maxWidth"]?.doubleValue.map { CGFloat($0) }

        let maxHeight: CGFloat? = props["maxHeight"]?.doubleValue.map { CGFloat($0) }

        if maxWidth != nil || maxHeight != nil {
            v = AnyView(
                v.frame(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight
                )
            )
        }
        

        // opacity
        if let opacity = props["opacity"]?.doubleValue {
            v = AnyView(v.opacity(opacity))
        }

        // corner radius
        if let corner = props["cornerRadius"]?.doubleValue {
            v = AnyView(
                v.clipShape(
                    RoundedRectangle(cornerRadius: CGFloat(corner))
                )
            )
        }

        // background color
        if let bg = Color.fromDynamic(props["backgroundColor"]) {
            v = AnyView(v.background(bg))
        }
        
        // foreground color
        if let fg = Color.fromDynamic(props["foregroundColor"]) {
            v = AnyView(v.foregroundStyle(fg))
        }

        return v
    }
}
