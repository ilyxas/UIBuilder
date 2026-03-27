import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ScreenHostView()
                .tabItem {
                    Label("Screen", systemImage: "iphone")
                }
                

            LocalLLMView()
                .tabItem {
                    Label("Local LLM", systemImage: "message")
                }
        }
    }
}
