//
//  WorldPOCView.swift
//  UIBuilder
//
//  Created by ilya on 05/04/2026.
//

import SwiftUI

@available(iOS 26.0, *)
struct WorldPOCView: View {
    let llm: LLMEvaluator
    let planner: WorldPlannerService
    
    @State private var vm: WorldPOCViewModel

    init(llm: LLMEvaluator, planner: WorldPlannerService) {
        self.llm = llm
        self.planner = planner
        _vm = State(initialValue: WorldPOCViewModel(llm: llm, planner: planner))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GamePieceViewRepresentable()
                    .frame(height: 320)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last world reaction")
                        .font(.headline)

                    ScrollView {
                        Text(vm.statusText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .font(.system(.footnote, design: .monospaced))
                        Text(String(describing: GameWorld.shared.state))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .font(.system(.footnote, design: .monospaced))
                    }
                    .frame(maxHeight: 180)
                    .padding(10)
                    .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Step") {
                            Task { await vm.stepTowardGoal() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(planner.chatModel.isBusy == true)

                        Button("Reset World") {
                            vm.resetWorld()
                        }
                        .buttonStyle(.bordered)

                        Button("Reset Session") {
                            vm.resetSession()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("World Interpretation POC")
            .onAppear {
                GameWorld.shared.start()
            }
            .onDisappear {
                GameWorld.shared.stop()
            }
        }
    }
}
