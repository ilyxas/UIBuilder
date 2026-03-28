//
//  LocalLLMView.swift
//  UIBuilder
//
//  Created by ilya on 26/03/2026.
//

import SwiftUI

struct LocalLLMView: View {
    @StateObject private var vm = LocalLLMViewModel()
    @State private var webViewId: String = "browser"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                modelBar

                Divider()

                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role.rawValue.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(message.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Generated Script Preview")
                        .font(.headline)

                    ScrollView {
                        Text(vm.generatedScript.isEmpty ? "No script generated yet." : vm.generatedScript)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(minHeight: 120, maxHeight: 180)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        TextField("WebView id", text: $webViewId)
                            .textFieldStyle(.roundedBorder)
                            .scrollDismissesKeyboard(.interactively)

                        Button("Send To WebView") {
                            Task {
                                await vm.sendScriptToWebView(webViewId: webViewId)
                            }
                        }
                        .disabled(vm.generatedScript.isEmpty)
                    }
                }
                .padding(.horizontal)

                Divider()

                VStack(spacing: 8) {
                    TextField("Message...", text: $vm.inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...6)
                        .scrollDismissesKeyboard(.interactively)

                    HStack {
                        Button("Send") {
                            Task { await vm.sendMessage() }
                        }
                        .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !vm.isModelLoaded)

                        Button("Generate Script") {
                            Task { await vm.generateScript() }
                        }
                        .disabled(!vm.isModelLoaded)

                        Spacer()

                        if vm.isGenerating {
                            ProgressView()
                        }
                    }
                    .ignoresSafeArea(.keyboard)
                }
                .padding()
            }
            .ignoresSafeArea(.keyboard)
            .alert("Error", isPresented: Binding(
                get: { vm.errorText != nil },
                set: { newValue in
                    if !newValue { vm.errorText = nil }
                }
            )) {
                Button("OK", role: .cancel) { vm.errorText = nil }
            } message: {
                Text(vm.errorText ?? "")
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private var modelBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model status: \(vm.isModelLoaded ? "Loaded" : "Not loaded")")
            Text("Current model: \(vm.selectedModelName)")
                .foregroundStyle(.secondary)

            HStack {
                TextField("Model name", text: $vm.selectedModelName)
                    .textFieldStyle(.roundedBorder)
                    .scrollDismissesKeyboard(.interactively)

                Button("Load") {
                    Task { await vm.loadModel() }
                }

                Button("Unload") {
                    vm.unloadModel()
                }
                .disabled(!vm.isModelLoaded)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
}
