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
                alignment: NodeStyle.horizontalAlignment(from: node.props?["alignment"]),
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
                    alignment: NodeStyle.horizontalAlignment(from: node.props?["alignment"]),
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
            // Semantic: props.label (required) + props.icon (optional SF Symbol).
            let button = Button {
                trigger(eventName: node.event?["tap"], evaluator: evaluator)
            } label: {
                let btnTitle = resolveText(from: node.props?["label"], evaluator: evaluator)
                let btnIcon = node.props?["icon"]?.stringValue
                if let btnIcon, !btnIcon.isEmpty {
                    Label(btnTitle, systemImage: btnIcon)
                } else {
                    Text(btnTitle)
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
            // Semantic node: icon + text, no manual hstack composition needed.
            // Props: title (string | bind | format), icon (SF Symbol name)
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
            // Composite node: Menu with label from first child (or props title/icon)
            // and actions/content from remaining children.
            // First child with id "label" or type "label" is used as the trigger label;
            // remaining children are menu items.
            let menuTitle = resolveText(from: node.props?["title"], evaluator: evaluator)
            let menuIcon = node.props?["icon"]?.stringValue
            let allChildren = node.children ?? []
            // First child may be an explicit label node for the menu trigger button
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
            // Semantic TabView. Children must be of type "tab".
            // Props: selection (optional bind to a state variable)
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
            // tab is used only inside tabview.
            // Outside tabview, children are rendered as a vstack.
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
            // Toolbar content comes exclusively from host.toolbar slots:
            // topLeading, topTrailing, bottomBar, principal.
            // children contains body content only.
            let navTitle = resolveText(from: node.props?["title"], evaluator: evaluator)

            NavigationStack {
                navigationBody(evaluator: evaluator)
                    .navigationTitle(navTitle)
                    .toolbar {
                        navigationToolbar(evaluator: evaluator)
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

        // MARK: - frame

        case "frame":
            // Container that applies explicit frame constraints and alignment to its children.
            // Props: alignment, idealWidth, idealHeight, fixedSize, clip, clipShape + common style props.
            let frameAlignment = NodeStyle.frameAlignment(from: node.props?["alignment"])
            NodeStyle.apply(
                ZStack(alignment: frameAlignment) {
                    ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                },
                props: node.props
            )

        // MARK: - textfield

        case "textfield":
            // Single-line text input bound to a state key.
            // Required: bind. Optional: placeholder, keyboardType, secure, autocapitalization,
            // autocorrectionDisabled, returnKeyType, maxLength, prefixIcon, suffixIcon.
            textFieldView(evaluator: evaluator)

        // MARK: - slider

        case "slider":
            // Continuous or stepped value slider bound to a state key.
            // Required: bind, min, max. Optional: step, label, accentColor.
            sliderView(evaluator: evaluator)

        // MARK: - shape

        case "shape":
            // Geometric shape node. Props: type, fill, strokeColor, strokeWidth, strokeStyle,
            // cornerRadius, cornerStyle. May contain children (rendered on top via ZStack).
            shapeView(evaluator: evaluator)

        // MARK: - group

        case "group":
            // Semantic grouping with optional title, footer, and collapsible behaviour.
            // Styles: plain (default), card, inset.
            groupView(evaluator: evaluator)

        // MARK: - table

        case "table":
            // Table container. Children of type "section" group rows; plain children are rows.
            // Props: rowHeight, selectionMode, alternatingRows, headerVisible, columns.
            tableView(evaluator: evaluator)

        default:
            Text("Unsupported node: \(node.type)")
        }
    }

    // Renders tab node content with .tabItem modifier.
    // Props: title (string), icon (SF Symbol name).
    @ViewBuilder
    private func tabContent(tab: UINode, evaluator: ExpressionEvaluator) -> some View {
        let tabTitle = resolveText(from: tab.props?["title"], evaluator: evaluator)
        let tabIcon = tab.props?["icon"]?.stringValue ?? ""

        VStack(spacing: 0) {
            ForEach(Array((tab.children ?? []).enumerated()), id: \.offset) { _, child in
                UIRenderer(node: child, document: document, state: state, executor: executor)
            }
        }
        .tabItem {
            if !tabIcon.isEmpty {
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

    // MARK: - TextField helper

    @ViewBuilder
    private func textFieldView(evaluator: ExpressionEvaluator) -> some View {
        let key         = node.props?["bind"]?.stringValue ?? ""
        let placeholder = node.props?["placeholder"]?.stringValue ?? ""
        let isSecure    = node.props?["secure"]?.boolValue ?? false
        let maxLength   = node.props?["maxLength"]?.doubleValue.map { Int($0) }

        let binding = Binding<String>(
            get: { state.get(key)?.stringValue ?? "" },
            set: { newValue in
                let capped = maxLength.map { String(newValue.prefix($0)) } ?? newValue
                state.set(key, value: .string(capped))
                trigger(eventName: node.event?["change"], evaluator: evaluator)
            }
        )

        let prefixIcon  = node.props?["prefixIcon"]?.stringValue
        let suffixIcon  = node.props?["suffixIcon"]?.stringValue

        let keyboardType = keyboardTypeValue(from: node.props?["keyboardType"])
        let submitLabel  = returnKeyTypeValue(from: node.props?["returnKeyType"])
        let autoCapitalization = autoCapitalizationValue(from: node.props?["autocapitalization"])
        let autocorrDisabled = node.props?["autocorrectionDisabled"]?.boolValue ?? false

        NodeStyle.apply(
            HStack(spacing: 4) {
                if let icon = prefixIcon, !icon.isEmpty {
                    Image(systemName: icon)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: binding)
                    } else {
                        TextField(placeholder, text: binding)
                            .keyboardType(keyboardType)
                            .submitLabel(submitLabel)
                            .textInputAutocapitalization(autoCapitalization)
                            .autocorrectionDisabled(autocorrDisabled)
                    }
                }
                if let icon = suffixIcon, !icon.isEmpty {
                    Image(systemName: icon)
                }
            },
            props: node.props
        )
    }

    // MARK: - Slider helper

    private func sliderView(evaluator: ExpressionEvaluator) -> AnyView {
        let key         = node.props?["bind"]?.stringValue ?? ""
        let minVal      = node.props?["min"]?.doubleValue ?? 0
        let maxVal      = node.props?["max"]?.doubleValue ?? 1
        let step        = node.props?["step"]?.doubleValue
        let label       = node.props?["label"]?.stringValue ?? ""
        let accentColor = Color.fromDynamic(node.props?["accentColor"])

        let binding = Binding<Double>(
            get: { self.state.get(key)?.doubleValue ?? minVal },
            set: { newValue in
                self.state.set(key, value: .number(newValue))
                self.trigger(eventName: self.node.event?["change"], evaluator: evaluator)
            }
        )

        let base: AnyView
        if let step {
            base = AnyView(
                Slider(value: binding, in: minVal...maxVal, step: step) { Text(label) }
            )
        } else {
            base = AnyView(
                Slider(value: binding, in: minVal...maxVal) { Text(label) }
            )
        }

        let tinted: AnyView = accentColor.map { AnyView(base.tint($0)) } ?? base
        return NodeStyle.apply(tinted, props: node.props)
    }

    // MARK: - Shape helper

    @ViewBuilder
    private func shapeView(evaluator: ExpressionEvaluator) -> some View {
        let shapeType   = node.props?["type"]?.stringValue ?? "rectangle"
        let fillColor   = Color.fromDynamic(node.props?["fill"])
        let strokeColor = Color.fromDynamic(node.props?["strokeColor"])
        let strokeWidth = CGFloat(node.props?["strokeWidth"]?.doubleValue ?? 1)
        let strokeStyleStr = node.props?["strokeStyle"]?.stringValue ?? "solid"
        let radius      = CGFloat(node.props?["cornerRadius"]?.doubleValue ?? 0)
        let children    = node.children ?? []

        let shapeStyle  = buildStrokeStyle(styleStr: strokeStyleStr, width: strokeWidth)

        let baseShape = AnyView(
            ZStack {
                builtShape(type: shapeType, radius: radius, fill: fillColor,
                           strokeColor: strokeColor, strokeStyle: shapeStyle)
                if !children.isEmpty {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        UIRenderer(node: child, document: document, state: state, executor: executor)
                    }
                }
            }
        )

        NodeStyle.apply(baseShape, props: node.props)
    }

    @ViewBuilder
    private func builtShape(type: String, radius: CGFloat, fill: Color?,
                            strokeColor: Color?, strokeStyle: StrokeStyle) -> some View {
        // Each case uses ZStack so @ViewBuilder always has a concrete View result,
        // even when both fill and strokeColor are nil.
        switch type {
        case "circle":
            ZStack {
                if let fill { Circle().fill(fill) }
                if let strokeColor { Circle().stroke(strokeColor, style: strokeStyle) }
            }
        case "capsule":
            ZStack {
                if let fill { Capsule().fill(fill) }
                if let strokeColor { Capsule().stroke(strokeColor, style: strokeStyle) }
            }
        case "ellipse":
            ZStack {
                if let fill { Ellipse().fill(fill) }
                if let strokeColor { Ellipse().stroke(strokeColor, style: strokeStyle) }
            }
        case "roundedRectangle":
            ZStack {
                if let fill { RoundedRectangle(cornerRadius: radius).fill(fill) }
                if let strokeColor { RoundedRectangle(cornerRadius: radius).stroke(strokeColor, style: strokeStyle) }
            }
        default: // rectangle
            ZStack {
                if let fill { Rectangle().fill(fill) }
                if let strokeColor { Rectangle().stroke(strokeColor, style: strokeStyle) }
            }
        }
    }

    private func buildStrokeStyle(styleStr: String, width: CGFloat) -> StrokeStyle {
        switch styleStr {
        case "dashed":  return StrokeStyle(lineWidth: width, dash: [6, 3])
        case "dotted":  return StrokeStyle(lineWidth: width, dash: [2, 3])
        default:        return StrokeStyle(lineWidth: width)
        }
    }

    // MARK: - Group helper

    @ViewBuilder
    private func groupView(evaluator: ExpressionEvaluator) -> some View {
        let title       = node.props?["title"]?.stringValue
        let footer      = node.props?["footer"]?.stringValue
        let collapsible = node.props?["collapsible"]?.boolValue ?? false
        let style       = node.props?["style"]?.stringValue ?? "plain"
        let stateKey    = (node.id ?? "group") + ".isExpanded"
        let defaultExpanded = node.props?["isExpanded"]?.boolValue ?? true

        let content = AnyView(
            ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                UIRenderer(node: child, document: document, state: state, executor: executor)
            }
        )

        let groupBody = AnyView(
            VStack(alignment: .leading, spacing: 0) {
                if collapsible {
                    let expanded = Binding<Bool>(
                        get: { state.get(stateKey)?.boolValue ?? defaultExpanded },
                        set: { state.set(stateKey, value: .bool($0)) }
                    )
                    DisclosureGroup(isExpanded: expanded) {
                        content
                    } label: {
                        Text(title ?? "").font(.headline)
                    }
                } else {
                    if let title {
                        Text(title).font(.headline).padding(.bottom, 4)
                    }
                    content
                    if let footer {
                        Text(footer).font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                    }
                }
            }
        )

        switch style {
        case "card":
            NodeStyle.apply(
                groupBody
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12)),
                props: node.props
            )
        case "inset":
            NodeStyle.apply(
                groupBody
                    .padding(.horizontal, 16),
                props: node.props
            )
        default: // plain
            NodeStyle.apply(groupBody, props: node.props)
        }
    }

    // MARK: - Table helper

    @ViewBuilder
    private func tableView(evaluator: ExpressionEvaluator) -> some View {
        // Table renders as a List with optional alternating row backgrounds.
        // Props: rowHeight, selectionMode, alternatingRows, headerVisible, columns.
        // Children of type "section" group rows; other children are direct rows.
        let rowHeight       = node.props?["rowHeight"]?.doubleValue.map { CGFloat($0) }
        let alternating     = node.props?["alternatingRows"]?.boolValue ?? false
        let headerVisible   = node.props?["headerVisible"]?.boolValue ?? true
        let columns         = node.props?["columns"]?.stringValue  // comma-separated column titles
        let selectionMode   = node.props?["selectionMode"]?.stringValue ?? "none"
        let children        = node.children ?? []

        // Selection binding (single mode uses a string key stored in state)
        let selectionKey = (node.id ?? "table") + ".selection"

        NodeStyle.apply(
            VStack(spacing: 0) {
                // Optional column header row
                if headerVisible, let columns {
                    let cols = columns.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    HStack {
                        ForEach(cols, id: \.self) { col in
                            Text(col)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))

                    Divider()
                }

                // Rows
                List {
                    ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                        let rowView = UIRenderer(node: child, document: document, state: state, executor: executor)
                        Group {
                            if alternating && index % 2 != 0 {
                                rowView
                                    .listRowBackground(Color(.systemFill))
                            } else {
                                rowView
                            }
                        }
                        .if(rowHeight != nil) { $0.frame(minHeight: rowHeight!) }
                        .if(selectionMode == "single") {
                            $0.onTapGesture {
                                state.set(selectionKey, value: .string(child.id ?? "\(index)"))
                            }
                        }
                    }
                }
                .listStyle(.plain)
            },
            props: node.props
        )
    }

    // MARK: - Keyboard / input helpers

    private func keyboardTypeValue(from value: DynamicValue?) -> UIKeyboardType {
        switch value?.stringValue {
        case "numberPad":   return .numberPad
        case "decimalPad":  return .decimalPad
        case "email":       return .emailAddress
        case "phone":       return .phonePad
        case "url":         return .URL
        default:            return .default
        }
    }

    private func returnKeyTypeValue(from value: DynamicValue?) -> SubmitLabel {
        switch value?.stringValue {
        case "done":   return .done
        case "go":     return .go
        case "search": return .search
        case "next":   return .next
        default:       return .done
        }
    }

    private func autoCapitalizationValue(from value: DynamicValue?) -> TextInputAutocapitalization {
        switch value?.stringValue {
        case "words":      return .words
        case "sentences":  return .sentences
        case "characters": return .characters
        default:           return .never
        }
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

    private func font(from style: String?) -> Font {
        switch style {
        case "title": return .title2.weight(.semibold)
        case "caption": return .caption
        default: return .body
        }
    }

    // MARK: - NavigationStack helpers

    // Renders the body content of a navigationstack node.
    // All children are body/content nodes. Toolbar content lives in host.toolbar, not here.
    @ViewBuilder
    private func navigationBody(evaluator: ExpressionEvaluator) -> some View {
        VStack(spacing: 0) {
            ForEach(Array((node.children ?? []).enumerated()), id: \.offset) { _, child in
                UIRenderer(node: child, document: document, state: state, executor: executor)
            }
        }
    }

    // Builds ToolbarContent for a navigationstack node from host.toolbar slots.
    @ToolbarContentBuilder
    private func navigationToolbar(evaluator: ExpressionEvaluator) -> some ToolbarContent {
        if let toolbar = node.host?.toolbar {
            if let nodes = toolbar.topLeading, !nodes.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    toolbarSlotView(nodes: nodes, evaluator: evaluator)
                }
            }
            if let nodes = toolbar.topTrailing, !nodes.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarSlotView(nodes: nodes, evaluator: evaluator)
                }
            }
            if let nodes = toolbar.principal, !nodes.isEmpty {
                ToolbarItem(placement: .principal) {
                    toolbarSlotView(nodes: nodes, evaluator: evaluator)
                }
            }
            if let nodes = toolbar.bottomBar, !nodes.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    toolbarSlotView(nodes: nodes, evaluator: evaluator)
                }
            }
        }
    }

    // Renders a single toolbar slot as a horizontal group of UINodes.
    @ViewBuilder
    private func toolbarSlotView(nodes: [UINode], evaluator: ExpressionEvaluator) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                UIRenderer(node: node, document: document, state: state, executor: executor)
            }
        }
    }
}
