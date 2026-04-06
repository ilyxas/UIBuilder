//
//  MiniWorldМшуц.swift
//  UIBuilder
//
//  Created by ilya on 06/04/2026.
//

import SwiftUI
import RealityKit


struct MiniWorldView: View {
    let planner: LevelPlannerService
    @State private var world: MiniWorld
    @State private var stick = CGSize.zero

    init(levelPlanner: LevelPlannerService) {
        self.planner = levelPlanner
        self.world = MiniWorld(planner: levelPlanner)
    }
    
    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .virtual
                content.add(world.root)

                _ = content.subscribe(to: SceneEvents.Update.self) { event in
                    Task { @MainActor in
                        world.step(dt: Float(event.deltaTime))
                    }
                }
            }

            VStack {
                Spacer()

                HStack(alignment: .bottom) {
                    joystick

                    Spacer()

                    Button {
                        world.requestJump()
                    } label: {
                        Text("JUMP")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
            }
        }
        .ignoresSafeArea()
    }

    private var joystick: some View {
        let size: CGFloat = 120
        let knob: CGFloat = 44
        let limit = (size - knob) / 2

        return ZStack {
            Circle()
                .fill(.thinMaterial)
                .frame(width: size, height: size)

            Circle()
                .fill(.ultraThickMaterial)
                .frame(width: knob, height: knob)
                .offset(stick)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    var x = value.translation.width
                    var y = value.translation.height
                    let len = hypot(x, y)

                    if len > limit, len > 0 {
                        x = x / len * limit
                        y = y / len * limit
                    }

                    stick = CGSize(width: x, height: y)

                    world.input = SIMD2<Float>(
                        Float(x / limit),
                        Float(y / limit)
                    )
                }
                .onEnded { _ in
                    stick = .zero
                    world.input = .zero
                }
        )
    }
}
