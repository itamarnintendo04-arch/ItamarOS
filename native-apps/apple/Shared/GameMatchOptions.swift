import SwiftUI

// Shared match setup for games with two competing players.
// "With a friend" means two people on the same device (local pass-and-play).
enum GameOpponent: String, CaseIterable, Identifiable {
    case friend = "With a friend"
    case bot = "Against a bot"
    var id: String { rawValue }
}

enum GameDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    var id: String { rawValue }
}

struct GameMatchOptions: View {
    @Binding var opponent: GameOpponent
    @Binding var difficulty: GameDifficulty

    var body: some View {
        VStack(spacing: 8) {
            Text("Who do you want to play against?").font(.subheadline.bold())
            Picker("Match", selection: $opponent) {
                ForEach(GameOpponent.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            if opponent == .bot {
                Picker("Bot difficulty", selection: $difficulty) {
                    ForEach(GameDifficulty.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Text("Pass this device to your friend when their turn begins.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
