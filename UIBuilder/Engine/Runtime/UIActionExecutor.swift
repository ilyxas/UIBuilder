import Foundation
import Observation

@MainActor
final class UIActionExecutor {
    let state: UIStateStore
    let navigation: NavigationStore

    var onToast: ((String) -> Void)?
    var onAlert: ((String, String) -> Void)?
    var onAIRequest: ((String, [String: DynamicValue]) -> Void)?

    init(state: UIStateStore, navigation: NavigationStore) {
        self.state = state
        self.navigation = navigation
    }

    func execute(_ actions: [UIAction], evaluator: ExpressionEvaluator) {
        for action in actions {
            if let when = action.when, evaluator.evaluateBool(when) == false {
                continue
            }

            switch action.action {
            case "state.set":
                guard let key = action.key, let value = action.value else { continue }
                state.set(key, value: value)

            case "state.inc":
                guard let key = action.key else { continue }
                state.increment(key, max: action.max)

            case "state.dec":
                guard let key = action.key else { continue }
                state.decrement(key, min: action.min)

            case "state.toggle":
                guard let key = action.key else { continue }
                state.toggle(key)

            case "nav.push":
                guard let screenId = action.screenId else { continue }
                navigation.push(screenId)

            case "nav.pop":
                navigation.pop()

            case "ui.toast":
                guard let message = action.message else { continue }
                onToast?(message)

            case "ui.alert":
                guard let title = action.title, let message = action.message else { continue }
                onAlert?(title, message)

            case "flow.emit":
                break

            case "ai.request":
                guard let id = action.id, let input = action.input else { continue }
                onAIRequest?(id, input)

            default:
                break
            }
        }
    }
}