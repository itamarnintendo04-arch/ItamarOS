import SwiftUI

/// Colorful native illustrated game cards, drawn locally and available offline.
struct GameArtworkView: View {
    let game: String

    private var palette: [Color] {
        switch game {
        case "Snake": return [.green, .mint]
        case "2048": return [.indigo, .cyan]
        case "Memory Match": return [.pink, .orange]
        case "Connect Four": return [.blue, .yellow]
        case "Tic-Tac-Toe": return [.teal, .blue]
        case "Number Guess": return [.purple, .orange]
        case "Reaction Test": return [.pink, .yellow]
        case "Math Sprint": return [.mint, .cyan]
        case "Word Mix": return [.purple, .pink]
        case "Rock Paper Scissors": return [.blue, .pink]
        default: return [.orange, .mint]
        }
    }

    private var scene: String {
        switch game {
        case "Snake": return "🐍  🍒"
        case "2048": return "🔢  ✨"
        case "Memory Match": return "🎴  💜"
        case "Tic-Tac-Toe": return "⭕  ❌"
        case "Number Guess": return "🔍  ❓"
        case "Reaction Test": return "⚡  🏁"
        case "Rock Paper Scissors": return "🪨  📄  ✂️"
        case "Math Sprint": return "➕  🧮"
        case "Word Mix": return "🔤  🌈"
        case "Pattern Memory": return "🟡  🟣  🔵"
        case "Connect Four": return "🔴  🟡"
        default: return "🎮  🌟"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 21)
                .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
            GeometryReader { geometry in
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: geometry.size.width * 0.34)
                    .offset(x: -26, y: -40)
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: geometry.size.width * 0.26)
                    .offset(x: geometry.size.width * 0.72, y: 32)
            }
            .clipped()
            Text(scene)
                .font(.system(size: 39))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 5)
        }
        .frame(height: 108)
        .accessibilityLabel(game + " colorful illustration")
    }
}

/// Hand-drawn native Snake/Cherry shapes instead of simple green-square text.
struct CartoonSnakeCell: View {
    let head: Bool
    let food: Bool
    let segment: Bool

    var bodyView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.85, green: 0.97, blue: 0.82))
            if food {
                ZStack {
                    Circle().fill(.red.gradient).frame(width: 13, height: 13).offset(x: -4, y: 4)
                    Circle().fill(.pink.gradient).frame(width: 13, height: 13).offset(x: 4, y: 4)
                    Capsule().fill(.brown).frame(width: 3, height: 9).rotationEffect(.degrees(24)).offset(y: -5)
                    Ellipse().fill(.green).frame(width: 10, height: 6).rotationEffect(.degrees(-30)).offset(x: 5, y: -8)
                }
            } else if head {
                Circle().fill(Color.green.gradient).padding(1)
                    .overlay {
                        HStack(spacing: 3) {
                            Circle().fill(.white).frame(width: 7, height: 7)
                                .overlay(Circle().fill(.black).frame(width: 3, height: 3))
                            Circle().fill(.white).frame(width: 7, height: 7)
                                .overlay(Circle().fill(.black).frame(width: 3, height: 3))
                        }
                        .offset(y: -3)
                    }
            } else if segment {
                Circle().fill(Color.mint.gradient).padding(2)
                    .overlay(Circle().stroke(Color.green.opacity(0.45), lineWidth: 1))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    var body: some View { bodyView }
}
