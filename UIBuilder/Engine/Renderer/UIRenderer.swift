import SwiftUI

struct UIRenderer: View {
    let node: UINode
    let document: ScreenDocument
    let state: UIStateStore
    let executor: UIActionExecutor

    var body: some View {
        let evaluator = ExpressionEvaluator(state: state)

        if let visibleWhen = node.visibleWhen, !evaluator.evaluateBool(visibleWhen) {
            EmptyView()
        } else {
            renderedNode(evaluator: evaluator)
                .disabled(node.enabledWhen.map { !evaluator.evaluateBool($0) } ?? false)
        }
    }

    @ViewBuilder
    private func renderedNode(evaluator: ExpressionEvaluator) -> some View {
        switch node.type {
        case "vstack":
            NodeStyle.apply(
            VStack(
                alignment: alignment(from: node.props?["alignment"]),
                spacing: CGFloat(node.props?["spacing"]?.doubleValue ?? 0)
            ) {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    UIRenderer(node: child, document: document, state: state, executor: executor)
                }
            },
            props: node.props
        )
        
        case "scroll":
            ScrollView(
                node.props?["axis"]?.stringValue == "horizontal" ? .horizontal : .vertical
            ) {
                VStack(
                    alignment: alignment(from: node.props?["alignment"]),
                    spacing: CGFloat(node.props?["spacing"]?.doubleValue ?? 0)
                ) {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                }
                .padding(CGFloat(node.props?["padding"]?.doubleValue ?? 0))
            }

        case "hstack":
            NodeStyle.apply(
                HStack(
                    alignment: .center,
                    spacing: CGFloat(node.props?["spacing"]?.doubleValue ?? 0)
                ) {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                },
                props: node.props
            )
            
        case "zstack":
            
            ZStack {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    UIRenderer(
                        node: child,
                        document: document,
                        state: state,
                        executor: executor
                    )
                }
            }
        case "text":
            NodeStyle.apply(
                Text(resolveText(from: node.props?["value"], evaluator: evaluator)),
                props: node.props
            )

        case "button":
            let button = Button {
                trigger(eventName: node.event?["tap"], evaluator: evaluator)
            } label: {
                HStack(spacing: CGFloat(node.props?["spacing"]?.doubleValue ?? 8)) {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                }
            }

            NodeStyle.apply(button, props: node.props)
            
        case "toggle":
            NodeStyle.apply(
            Toggle(
                resolveText(from: node.props?["title"], evaluator: evaluator),
                isOn: Binding(
                    get: { state.get(node.props?["bind"]?.stringValue ?? "")?.boolValue ?? false },
                    set: { newValue in
                        if let key = node.props?["bind"]?.stringValue {
                            state.set(key, value: .bool(newValue))
                            trigger(eventName: node.event?["change"], evaluator: evaluator)
                        }
                    }
                )
            ),
            props: node.props
        )
            
        case "icon":
            NodeStyle.apply(
                Image(systemName: node.props?["name"]?.stringValue ?? "questionmark")
                    .font(.system(size: node.props?["size"]?.doubleValue ?? 20)),
                props: node.props
            )

        case "spacer":
            Spacer()
            
        case "badge":
            Text(resolveText(from: node.props?["text"], evaluator: evaluator))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.15), in: Capsule())

        default:
            Text("Unsupported node: \(node.type)")
        }
    }

    private func trigger(eventName: String?, evaluator: ExpressionEvaluator) {
        guard let eventName, let actions = document.events[eventName] else { return }
        executor.execute(actions, evaluator: evaluator)
    }

    private func resolveText(from value: DynamicValue?, evaluator: ExpressionEvaluator) -> String {
        guard let value else { return "" }

        switch value {
        case .string(let string):
            return string

        case .object(let object):
            if let bind = object["bind"]?.stringValue {
                return state.get(bind)?.stringValue
                    ?? state.get(bind)?.doubleValue.map { String(describing: $0) }
                    ?? state.get(bind)?.boolValue.map { String(describing: $0) }
                    ?? ""
            }

            if case .string(let format)? = object["format"] {
                var result = format
                if case .array(let binds)? = object["binds"] {
                    for bindValue in binds {
                        if case .string(let key) = bindValue {
                            let replacement =
                                state.get(key)?.stringValue
                                ?? state.get(key)?.doubleValue.map { String(describing: $0) }
                                ?? state.get(key)?.boolValue.map { String(describing: $0) }
                                ?? ""
                            result = result.replacingOccurrences(of: "{\(key)}", with: replacement)
                        }
                    }
                }
                return result
            }

            return ""

        default:
            return ""
        }
    }

    private func alignment(from value: DynamicValue?) -> HorizontalAlignment {
        switch value?.stringValue {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    private func font(from style: String?) -> Font {
        switch style {
        case "title": return .title2.weight(.semibold)
        case "caption": return .caption
        default: return .body
        }
    }
}
