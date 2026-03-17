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
            NodeStyle.apply(
            ZStack {
                ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                    UIRenderer(
                        node: child,
                        document: document,
                        state: state,
                        executor: executor
                    )
                }
            },
            props: node.props
            )
        case "text":
            NodeStyle.apply(
                Text(resolveText(from: node.props?["value"], evaluator: evaluator)),
                props: node.props
            )

        case "button":
            // Semantic path: use props.label + props.icon to build the label.
            // Legacy path: if children are present, render them directly as the label.
            let button = Button {
                trigger(eventName: node.event?["tap"], evaluator: evaluator)
            } label: {
                if let children = node.children, !children.isEmpty {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                } else {
                    let btnTitle = resolveText(from: node.props?["label"], evaluator: evaluator)
                    let btnIcon = node.props?["icon"]?.stringValue
                    if let btnIcon, !btnIcon.isEmpty {
                        Label(btnTitle, systemImage: btnIcon)
                    } else {
                        Text(btnTitle)
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

        case "label":
            // Semantic node: icon + text без ручной сборки hstack.
            // Props: title (string | bind | format), icon (SF Symbol name), size (font size for icon)
            let labelTitle = resolveText(from: node.props?["title"], evaluator: evaluator)
            let iconName = node.props?["icon"]?.stringValue ?? ""
            NodeStyle.apply(
                Label {
                    Text(labelTitle)
                } icon: {
                    if !iconName.isEmpty {
                        Image(systemName: iconName)
                    }
                },
                props: node.props
            )

        case "menu":
            // Composite node: Menu с label из первого child (или props title/icon)
            // и действиями/контентом из остальных children.
            // Структура: первый child с id "label" (или props title+icon) — лейбл,
            // остальные children — пункты меню.
            let menuTitle = resolveText(from: node.props?["title"], evaluator: evaluator)
            let menuIcon = node.props?["icon"]?.stringValue
            let allChildren = node.children ?? []
            // Первый child может быть явным label-нодой для кнопки меню
            let labelChild = allChildren.first(where: { $0.id == "label" || $0.type == "label" })
            let menuItems = allChildren.filter { $0.id != "label" && $0.type != "label" }

            NodeStyle.apply(
                Menu {
                    ForEach(Array(menuItems.enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                } label: {
                    if let labelChild {
                        UIRenderer(node: labelChild, document: document, state: state, executor: executor)
                    } else if let menuIcon {
                        Label(menuTitle, systemImage: menuIcon)
                    } else {
                        Text(menuTitle)
                    }
                },
                props: node.props
            )

        case "tabview":
            // Semantic TabView. Children должны быть типа "tab".
            // Props: selection (bind к state-переменной, опционально)
            let tabs = (node.children ?? []).filter { $0.type == "tab" }
            if let selectionKey = node.props?["selection"]?.stringValue {
                let binding = Binding<String>(
                    get: { state.get(selectionKey)?.stringValue ?? (tabs.first?.id ?? "") },
                    set: { newValue in state.set(selectionKey, value: .string(newValue)) }
                )
                NodeStyle.apply(
                    TabView(selection: binding) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                            tabContent(tab: tab, evaluator: evaluator)
                                .tag(tab.id ?? "tab_\(tabs.firstIndex(where: { $0.id == tab.id }) ?? 0)")
                        }
                    },
                    props: node.props
                )
            } else {
                NodeStyle.apply(
                    TabView {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                            tabContent(tab: tab, evaluator: evaluator)
                        }
                    },
                    props: node.props
                )
            }

        case "tab":
            // tab используется только внутри tabview.
            // Вне tabview рендерим children как vstack.
            NodeStyle.apply(
                VStack(spacing: 0) {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                },
                props: node.props
            )

        case "image":
            // Semantic image node. Props: systemName (SF Symbol) or name (asset catalog),
            // contentMode ("fit" | "fill", default "fit").
            let fillMode = node.props?["contentMode"]?.stringValue == "fill"
            if let systemName = node.props?["systemName"]?.stringValue {
                NodeStyle.apply(
                    Image(systemName: systemName)
                        .resizable()
                        .aspectRatio(contentMode: fillMode ? .fill : .fit),
                    props: node.props
                )
            } else if let assetName = node.props?["name"]?.stringValue {
                NodeStyle.apply(
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: fillMode ? .fill : .fit),
                    props: node.props
                )
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

        case "navigationstack":
            // NavigationStack owning the navigation context.
            // Props: title (navigation bar title, optional).
            // toolbaritem children are lifted into the toolbar; all other children
            // are rendered as vertical content.
            let navTitle = resolveText(from: node.props?["title"], evaluator: evaluator)
            let allNavChildren = node.children ?? []
            let toolbarNodes = allNavChildren.filter { $0.type == "toolbaritem" }
            let contentNodes = allNavChildren.filter { $0.type != "toolbaritem" }

            NavigationStack {
                VStack(spacing: 0) {
                    ForEach(Array(contentNodes.enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                }
                .navigationTitle(navTitle)
                .toolbar {
                    toolbarContent(nodes: toolbarNodes, evaluator: evaluator)
                }
            }

        case "list":
            // Vertical document-style content list.
            // Children are rendered as List rows; section children group naturally.
            NodeStyle.apply(
                List {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                },
                props: node.props
            )

        case "section":
            // Section grouping, fits naturally inside list.
            // Props: title (optional header string).
            let sectionTitle = resolveText(from: node.props?["title"], evaluator: evaluator)
            if sectionTitle.isEmpty {
                Section {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                }
            } else {
                Section(sectionTitle) {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                }
            }

        case "toolbaritem":
            // toolbaritem is handled natively by navigationstack.
            // When used outside that context, children are rendered as a plain view group.
            ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                UIRenderer(node: child, document: document, state: state, executor: executor)
            }

        default:
            Text("Unsupported node: \(node.type)")
        }
    }

    // Рендерит содержимое tab-ноды с .tabItem модификатором.
    // Props tab-ноды: title (string), icon (SF Symbol name).
    @ViewBuilder
    private func tabContent(tab: UINode, evaluator: ExpressionEvaluator) -> some View {
        let tabTitle = resolveText(from: tab.props?["title"], evaluator: evaluator)
        let tabIcon = tab.props?["icon"]?.stringValue

        VStack(spacing: 0) {
            ForEach(Array((tab.children ?? []).enumerated()), id: \.offset) { _, child in
                UIRenderer(node: child, document: document, state: state, executor: executor)
            }
        }
        .tabItem {
            if let tabIcon {
                Label(tabTitle, systemImage: tabIcon)
            } else {
                Text(tabTitle)
            }
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

    // Builds ToolbarContent for navigationstack from toolbaritem children.
    @ToolbarContentBuilder
    private func toolbarContent(nodes: [UINode], evaluator: ExpressionEvaluator) -> some ToolbarContent {
        ForEach(Array(nodes.enumerated()), id: \.offset) { _, item in
            ToolbarItem(placement: toolbarPlacement(from: item.props?["placement"])) {
                ForEach(Array((item.children ?? []).enumerated()), id: \.offset) { _, child in
                    UIRenderer(node: child, document: document, state: state, executor: executor)
                }
            }
        }
    }

    private func toolbarPlacement(from value: DynamicValue?) -> ToolbarItemPlacement {
        switch value?.stringValue {
        case "leading": return .topBarLeading
        case "trailing": return .topBarTrailing
        case "bottom": return .bottomBar
        default: return .automatic
        }
    }
}
