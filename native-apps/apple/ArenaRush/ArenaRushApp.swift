import SwiftUI
import SpriteKit

@main
struct ArenaRushApp: App {
    var body: some Scene {
        WindowGroup { ArenaRushHome().statusBarHidden().persistentSystemOverlays(.hidden) }
    }
}

private enum ArenaStyle {
    static let dark = Color(red: 0.06, green: 0.09, blue: 0.18)
    static let accent = Color(red: 0.31, green: 0.93, blue: 0.79)
}

struct ArenaRushHome: View {
    @State private var gameStarted = false
    @State private var difficulty = 1
    @State private var chosenHero = 0
    @AppStorage("arenarush.best") private var best = 0
    private let heroes = ["Nova", "Volt", "Ember"]
    var body: some View {
        ZStack {
            LinearGradient(colors: [ArenaStyle.dark, Color(red: 0.13, green: 0.11, blue: 0.37)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            if gameStarted {
                ArenaRushMatch(hero: chosenHero, difficulty: difficulty) { score in
                    best = max(best, score)
                    gameStarted = false
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("ARENA RUSH").font(.system(size: 52, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("BY ITAMAROS").font(.headline).foregroundStyle(ArenaStyle.accent)
                        Text("Original top-down arena battles").foregroundStyle(.white.opacity(0.7))
                        HStack(spacing: 18) {
                            ForEach(heroes.indices, id: \.self) { i in
                                Button {
                                    chosenHero = i
                                } label: {
                                    VStack(spacing: 10) {
                                        Image(systemName: ["sparkles", "bolt.fill", "flame.fill"][i])
                                            .font(.system(size: 36))
                                            .frame(width: 84, height: 84)
                                            .background([Color.cyan, .yellow, .orange][i].opacity(0.23), in: RoundedRectangle(cornerRadius: 20))
                                        Text(heroes[i]).font(.headline)
                                    }
                                    .foregroundStyle(chosenHero == i ? ArenaStyle.accent : .white)
                                    .padding(8)
                                    .background(chosenHero == i ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 20))
                                }.buttonStyle(.plain)
                            }
                        }
                        Picker("Difficulty", selection: $difficulty) {
                            Text("Easy").tag(0)
                            Text("Normal").tag(1)
                            Text("Hard").tag(2)
                        }.pickerStyle(.segmented).frame(maxWidth: 390)
                        Text("Best score: \(best)").foregroundStyle(.white)
                        Button { gameStarted = true } label: {
                            Label("PLAY", systemImage: "play.fill")
                                .font(.title2.bold()).frame(maxWidth: 310).padding(16)
                        }
                        .buttonStyle(.borderedProminent).tint(ArenaStyle.accent)
                        Text("Left thumb: move  •  Right thumb: aim and shoot  •  SUPER: area blast")
                            .font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 400)
                }
            }
        }
    }
}

private struct ArenaRushMatch: View {
    let hero: Int
    let difficulty: Int
    let onFinish: (Int) -> Void
    @State private var scene: ArenaScene
    @State private var lastScore = 0
    @State private var health = 100
    @State private var superCharge = 0.0
    @State private var remaining = 120
    @State private var ended = false
    @State private var paused = false
    @State private var timer: Timer?
    init(hero: Int, difficulty: Int, onFinish: @escaping (Int) -> Void) {
        self.hero = hero
        self.difficulty = difficulty
        self.onFinish = onFinish
        _scene = State(initialValue: ArenaScene(size: CGSize(width: 1000, height: 560), hero: hero, difficulty: difficulty))
    }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                VStack {
                    HStack(spacing: 18) {
                        Label("\(health)", systemImage: "heart.fill").foregroundStyle(.red)
                        Label("\(lastScore)", systemImage: "star.fill").foregroundStyle(.yellow)
                        Text("\(remaining)s").monospacedDigit()
                        Spacer()
                        Button(paused ? "Resume" : "Pause") {
                            paused.toggle()
                            scene.isPaused = paused
                        }
                        .buttonStyle(.bordered)
                        Button("Exit") { stop(); onFinish(lastScore) }
                            .buttonStyle(.bordered)
                    }
                    .font(.headline.bold())
                    .padding(10)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                    Spacer()
                    HStack(alignment: .bottom) {
                        ArenaJoystick(label: "MOVE") { vector in scene.moveInput = vector }
                        Spacer()
                        Button {
                            scene.activateSuper()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "burst.fill").font(.title)
                                Text("SUPER \(Int(superCharge * 100))%").font(.caption2.bold())
                            }
                            .frame(width: 90, height: 75)
                            .background(superCharge >= 1 ? Color.yellow : Color.gray.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .disabled(superCharge < 1)
                        .foregroundStyle(.white)
                        ArenaJoystick(label: "FIRE") { vector in scene.fireInput = vector }
                    }
                    .padding(.horizontal, 35)
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 16)
                if ended {
                    VStack(spacing: 12) {
                        Text(health <= 0 ? "MATCH OVER" : "TIME UP")
                            .font(.system(size: 38, weight: .black))
                        Text("Score: \(lastScore)").font(.title2.bold())
                        Button("Back to menu") { stop(); onFinish(lastScore) }
                            .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(.white)
                    .padding(36)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                }
            }
            .onAppear {
                scene.scaleMode = .resizeFill
                scene.onState = { hp, score, charge in
                    health = hp
                    lastScore = score
                    superCharge = charge
                    if hp <= 0 { ended = true; scene.isPaused = true }
                }
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    if !paused && !ended {
                        remaining -= 1
                        if remaining <= 0 { ended = true; scene.isPaused = true }
                    }
                }
            }
            .onDisappear(perform: stop)
        }
    }
    private func stop() {
        timer?.invalidate()
        timer = nil
        scene.isPaused = true
    }
}

private struct ArenaJoystick: View {
    let label: String
    let onMove: (CGVector) -> Void
    @State private var drag = CGSize.zero
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle().fill(.black.opacity(0.4)).frame(width: 114, height: 114)
                Circle().stroke(.white.opacity(0.4), lineWidth: 3).frame(width: 114, height: 114)
                Circle().fill(.white.opacity(0.75)).frame(width: 48, height: 48).offset(drag)
            }
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let x = v.translation.width, y = v.translation.height
                    let d = max(1, hypot(x, y))
                    let k = min(48, d) / d
                    drag = CGSize(width: x*k, height: y*k)
                    onMove(CGVector(dx: drag.width/48, dy: -drag.height/48))
                }
                .onEnded { _ in drag = .zero; onMove(.zero) })
            Text(label).font(.caption.bold()).foregroundStyle(.white)
        }
    }
}
