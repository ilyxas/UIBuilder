# WebView Feature — Dev Log

## Контекст

Этот файл описывает ключевые архитектурные решения и обсуждения при разработке `webview` ноды и `eval` экшена в UIBuilder.

---

## Архитектура WebView

### WebViewRegistry (singleton)
```swift
private var stores: [String: WebViewStore] = [:]
```
- Словарь `id → WebViewStore`
- Один реестр на всё приложение
- Каждый `webview` нод регистрируется по своему `id`
- `eval` экшен таргетирует конкретный webview по `id`

### WebViewStore
- Хранит `WKWebView` объект
- `config.websiteDataStore = .default()` — cookies, localStorage персистентны
- `customUserAgent` — сайты думают что это Safari Mobile
- `allowsBackForwardNavigationGestures = true`

### WebViewRepresentable
- `UIViewRepresentable` обёртка над `WKWebView`
- `makeUIView` возвращает существующий `webView` из store (не создаёт новый)
- `updateUIView` пустой — SwiftUI не управляет состоянием webview

### Lifecycle проблема
```swift
.onDisappear {
    WebViewRegistry.shared.remove(id: nodeId)
}
```
- При уходе с экрана `WKWebView` удаляется из registry
- History, DOM состояние — всё теряется
- При возврате webview пересоздаётся с нуля
- Для браузера это нужно пересмотреть

---

## eval action

```json
{ "do": "eval", "target": "browser", "script": "history.back();" }
```

- `target` — id webview ноды в том же документе
- `script` — сырой JS, выполняется в контексте webview
- Единственный способ взаимодействия между SwiftUI и webview DOM

### Навигация через JS
```javascript
history.back()
history.forward()
history.go(-1)
window.location.href = 'https://example.com'
```

---

## State → JS Bridge проблема

**Ключевая архитектурная проблема:** SwiftUI state и JS `window` — два разных мира.

- `eval` скрипт не может читать SwiftUI state напрямую
- `textfield` bound к `urlInput` — значение живёт в SwiftUI
- Передать `urlInput` в `eval` script напрямую невозможно

### Workaround (использован в browser-app.json)
Домашняя страница содержит HTML input, который при нажатии Go устанавливает:
```javascript
window.__ub_url = inputValue;
window.location.href = inputValue;
```
Затем `navigateTo` eval читает `window.__ub_url`.

---

## Browser App (PR #23)

Полноценный браузер собранный целиком на JSON + eval.

### Структура
```
navigationstack "Browser"
└── vstack (spacing: 0)
    ├── hstack (URL bar)
    │   ├── textfield (bind: urlInput)
    │   └── button "Go" → navigateTo
    ├── hstack (stats bar, visibleWhen: statsBarOpen)
    │   ├── text "⏱ 00:00:00"  ← статичный placeholder
    │   ├── button "Reset" → resetTimer
    │   ├── textfield (bind: searchTerm)
    │   ├── button "↑" → searchUp
    │   └── button "↓" → searchDown
    ├── webview (id: "main-browser")
    ├── hstack (menu panel, visibleWhen: menuOpen)
    │   ├── button "🌐" → translatePage
    │   ├── button "💬" → findChat
    │   └── button "📊" → toggleStatsBar
    └── hstack (bottom toolbar)
        ├── button "‹" → goBack
        ├── button "›" → goForward
        ├── button "🏠" → goHome
        └── button "···" → toggleMenu
```

### Events

| Event | Механизм |
|---|---|
| `navigateTo` | `window.__ub_url \|\| 'https://example.com'` |
| `goBack` | `history.back()` |
| `goForward` | `history.forward()` |
| `goHome` | `document.open/write/close` — инжектирует полную HTML страницу |
| `toggleMenu` | `state.toggle` на `menuOpen` |
| `translatePage` | Google Translate redirect `?sl=auto&tl=ru&u=...` |
| `findChat` | `querySelectorAll` chat-like селекторы → `3px solid #FF3B30` border |
| `toggleStatsBar` | `state.toggle` на `statsBarOpen` |
| `resetTimer` | Инжектирует `position:fixed` overlay в webview DOM с `setInterval` |
| `searchUp` | `window.find(term, false, true)` |
| `searchDown` | `window.find(term, false, false)` |

### Home Page
Домашняя страница инжектируется через `document.write` при нажатии 🏠:
- Тёмная тема (`#1C1C1E` background)
- Device stats: `navigator.userAgent`, `navigator.language`, `navigator.onLine`, `navigator.hardwareConcurrency`, `screen.width/height`, `window.devicePixelRatio`, timezone, date
- Browsing history из `localStorage.__ub_history__` (последние 50 записей)
- HTML input + Go кнопка для навигации (устанавливает `window.__ub_url`)

---

## Известные ограничения

### Таймер
Таймер в stats bar (`resetTimer`) живёт внутри webview DOM как `position:fixed` overlay.
- При смене страницы — таймер пропадает
- SwiftUI `text "⏱ 00:00:00"` в stats bar — статичный, никогда не обновляется
- Правильное решение требует нативного расширения рантайма

### History при переключении табов
`onDisappear` удаляет webview из registry → history теряется.
Для браузера нужен lifecycle tied to screen, не to node.

### searchTerm vs urlInput
Профессор добавил отдельную переменную `searchTerm` — правильное решение чтобы не затирать URL при поиске.

---

## Следующие шаги

- [ ] `WKNavigationDelegate` в `WebViewStore` — `@Published var currentURL`, `var canGoBack`, `var canGoForward`
- [ ] Lifecycle fix — webview живёт пока жив экран, не нода
- [ ] Нативный таймер через рантайм событие
- [ ] История браузинга через нативный bridge, не только localStorage
