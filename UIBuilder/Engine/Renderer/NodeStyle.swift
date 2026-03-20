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

        // padding (individual sides take priority over uniform padding)
        let paddingTop      = props["paddingTop"]?.doubleValue.map    { CGFloat($0) }
        let paddingBottom   = props["paddingBottom"]?.doubleValue.map { CGFloat($0) }
        let paddingLeading  = props["paddingLeading"]?.doubleValue.map  { CGFloat($0) }
        let paddingTrailing = props["paddingTrailing"]?.doubleValue.map { CGFloat($0) }

        if paddingTop != nil || paddingBottom != nil || paddingLeading != nil || paddingTrailing != nil {
            v = AnyView(v.padding(EdgeInsets(
                top:      paddingTop ?? 0,
                leading:  paddingLeading ?? 0,
                bottom:   paddingBottom ?? 0,
                trailing: paddingTrailing ?? 0
            )))
        } else if let padding = props["padding"]?.doubleValue {
            v = AnyView(v.padding(CGFloat(padding)))
        }

        // width / height
        let width: CGFloat?  = props["width"]?.doubleValue.map  { CGFloat($0) }
        let height: CGFloat? = props["height"]?.doubleValue.map { CGFloat($0) }

        if width != nil || height != nil {
            v = AnyView(v.frame(width: width, height: height))
        }

        // minWidth / minHeight
        let minWidth: CGFloat?  = props["minWidth"]?.doubleValue.map  { CGFloat($0) }
        let minHeight: CGFloat? = props["minHeight"]?.doubleValue.map { CGFloat($0) }

        if minWidth != nil || minHeight != nil {
            v = AnyView(v.frame(minWidth: minWidth, minHeight: minHeight))
        }

        // maxWidth / maxHeight
        let maxWidth: CGFloat? = (props["maxWidth"]?.stringValue == "infinity")
            ? CGFloat.infinity
            : props["maxWidth"]?.doubleValue.map { CGFloat($0) }
        let maxHeight: CGFloat? = (props["maxHeight"]?.stringValue == "infinity")
            ? CGFloat.infinity
            : props["maxHeight"]?.doubleValue.map { CGFloat($0) }

        if maxWidth != nil || maxHeight != nil {
            v = AnyView(v.frame(maxWidth: maxWidth, maxHeight: maxHeight))
        }

        // idealWidth / idealHeight
        let idealWidth: CGFloat?  = props["idealWidth"]?.doubleValue.map  { CGFloat($0) }
        let idealHeight: CGFloat? = props["idealHeight"]?.doubleValue.map { CGFloat($0) }

        if idealWidth != nil || idealHeight != nil {
            v = AnyView(v.frame(idealWidth: idealWidth, idealHeight: idealHeight))
        }

        // fixedSize
        if let fixedStr = props["fixedSize"]?.stringValue {
            switch fixedStr {
            case "horizontal": v = AnyView(v.fixedSize(horizontal: true, vertical: false))
            case "vertical":   v = AnyView(v.fixedSize(horizontal: false, vertical: true))
            case "both":       v = AnyView(v.fixedSize())
            default: break
            }
        } else if props["fixedSize"]?.boolValue == true {
            v = AnyView(v.fixedSize())
        }

        // opacity
        if let opacity = props["opacity"]?.doubleValue {
            v = AnyView(v.opacity(opacity))
        }

        // background color (before clipping so cornerRadius clips it correctly)
        if let bg = Color.fromDynamic(props["backgroundColor"]) {
            v = AnyView(v.background(bg))
        }

        // clipShape / cornerRadius (after background)
        if let clipShapeStr = props["clipShape"]?.stringValue {
            v = AnyView(applyClipShape(v, shape: clipShapeStr,
                                       cornerRadius: props["cornerRadius"]?.doubleValue))
        } else if let corner = props["cornerRadius"]?.doubleValue {
            v = AnyView(v.clipShape(RoundedRectangle(cornerRadius: CGFloat(corner))))
        }

        // clip (clips to bounds without a specific shape)
        if props["clip"]?.boolValue == true {
            v = AnyView(v.clipped())
        }

        // foreground color
        if let fg = Color.fromDynamic(props["foregroundColor"]) {
            v = AnyView(v.foregroundStyle(fg))
        }

        // shadow
        let shadowColor  = Color.fromDynamic(props["shadowColor"]) ?? Color.black.opacity(0.2)
        let shadowRadius = props["shadowRadius"]?.doubleValue.map { CGFloat($0) }
        let shadowX      = CGFloat(props["shadowX"]?.doubleValue ?? 0)
        let shadowY      = CGFloat(props["shadowY"]?.doubleValue ?? 0)
        if let shadowRadius {
            v = AnyView(v.shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY))
        }

        // border
        if let borderColor = Color.fromDynamic(props["borderColor"]) {
            let borderWidth = CGFloat(props["borderWidth"]?.doubleValue ?? 1)
            v = AnyView(v.overlay(
                RoundedRectangle(cornerRadius: CGFloat(props["cornerRadius"]?.doubleValue ?? 0))
                    .stroke(borderColor, lineWidth: borderWidth)
            ))
        }

        return v
    }

    // MARK: - Clip shape helper

    private static func applyClipShape(_ view: AnyView, shape: String, cornerRadius: Double?) -> AnyView {
        let radius = CGFloat(cornerRadius ?? 0)
        switch shape {
        case "circle":           return AnyView(view.clipShape(Circle()))
        case "capsule":          return AnyView(view.clipShape(Capsule()))
        case "ellipse":          return AnyView(view.clipShape(Ellipse()))
        case "roundedRectangle": return AnyView(view.clipShape(RoundedRectangle(cornerRadius: radius)))
        default:                 return AnyView(view.clipShape(Rectangle()))
        }
    }

    // MARK: - Alignment helpers

    /// Horizontal alignment from a string prop value.
    static func horizontalAlignment(from value: DynamicValue?) -> HorizontalAlignment {
        switch value?.stringValue {
        case "center":   return .center
        case "trailing": return .trailing
        default:         return .leading
        }
    }

    /// Vertical alignment from a string prop value.
    static func verticalAlignment(from value: DynamicValue?) -> VerticalAlignment {
        switch value?.stringValue {
        case "top":    return .top
        case "bottom": return .bottom
        default:       return .center
        }
    }

    /// Frame alignment (2D) from a string prop value.
    static func frameAlignment(from value: DynamicValue?) -> Alignment {
        switch value?.stringValue {
        case "topLeading":     return .topLeading
        case "top":            return .top
        case "topTrailing":    return .topTrailing
        case "leading":        return .leading
        case "center":         return .center
        case "trailing":       return .trailing
        case "bottomLeading":  return .bottomLeading
        case "bottom":         return .bottom
        case "bottomTrailing": return .bottomTrailing
        default:               return .center
        }
    }
}
