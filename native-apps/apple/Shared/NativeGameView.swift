import SwiftUI

struct NativeGameView: View {
    @AppStorage("itamaros.games.bestGuessStreak") private var best = 0
    @State private var selectedGame: String?
    @State private var target = Int.random(in: 1...100)
    @State private var guess = 50
    @State private var streak = 0
    @State private var result = "Guess a number from 1 to 100."
    @State private var board = Array(repeating: "", count: 9)
    @State private var turn = "X"
    @State private var winner = ""
    @State private var opponent: GameOpponent = .friend
    @State private var difficulty: GameDifficulty = .medium
    @State private var ticRoundID = UUID()
    private let games = ["2048", "Snake", "Memory Match", "Tic-Tac-Toe", "Number Guess",
                         "Reaction Test", "Rock Paper Scissors", "Math Sprint", "Word Mix",
                         "Pattern Memory", "Connect Four"]
    private let gameSymbols: [String: String] = [
        "2048": "square.grid.3x3.fill",
        "Snake": "point.topleft.down.curvedto.point.bottomright.up",
        "Memory Match": "rectangle.on.rectangle.angled",
        "Tic-Tac-Toe": "number.square.fill",
        "Number Guess": "questionmark.circle.fill",
        "Reaction Test": "bolt.circle.fill",
        "Rock Paper Scissors": "hand.raised.fill",
        "Math Sprint": "plus.forwardslash.minus",
        "Word Mix": "character.book.closed.fill",
        "Pattern Memory": "circle.hexagongrid.fill",
        "Connect Four": "circle.grid.3x3.fill"
    ]
    private let winLines = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let selectedGame {
                        HStack {
                            Button {
                                self.selectedGame = nil
                            } label: {
                                Label("All games", systemImage: "chevron.left")
                            }
                            Spacer()
                            Text(selectedGame).font(.headline)
                        }
                        .buttonStyle(.bordered)
                        GameArtworkView(game: selectedGame)

                        if selectedGame == "Number Guess" { numberGuess }
                        else if selectedGame == "Tic-Tac-Toe" { ticTacToe }
                        else { ExtraMobileGames(game: selectedGame) }
                    } else {
                        Text("Choose a game to start")
                            .font(.title2.bold())
                        Text("11 offline games")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [
                            GridItem(.flexible()), GridItem(.flexible())
                        ], spacing: 14) {
                            ForEach(games, id: \.self) { name in
                                Button {
                                    selectedGame = name
                                } label: {
                                    VStack(spacing: 13) {
                                        GameArtworkView(game: name)
                                            .frame(height: 75)
                                            .clipped()
                                        Text(name)
                                            .font(.subheadline.bold())
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 110)
                                    .padding(8)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    Text("Your best scores are saved locally on this device.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Games")
        }
    }

    private var numberGuess: some View {
        VStack(spacing: 14) {
            Text("Number Guess").font(.title2.bold())
            Text(result)
            Text("Guess: \(guess)").font(.title2)
            #if os(tvOS)
            HStack {
                Button("Lower") { guess = max(1, guess - 1) }
                Button("Higher") { guess = min(100, guess + 1) }
            }
            #else
            Slider(value: Binding(
                get: { Double(guess) },
                set: { guess = min(100, max(1, Int($0.rounded()))) }
            ), in: 1...100, step: 1)
                .accessibilityLabel("Slide to choose a number")
            #endif
            Button("Submit guess") { submitGuess() }.buttonStyle(.borderedProminent)
            Text("Streak: \(streak) · Best: \(best)").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var ticTacToe: some View {
        VStack(spacing: 16) {
            Text("Tic-Tac-Toe").font(.title2.bold())
            GameMatchOptions(opponent: $opponent, difficulty: $difficulty)
                .onChange(of: opponent) { _, _ in resetTic() }
                .onChange(of: difficulty) { _, _ in resetTic() }
            Text(winner.isEmpty ? (turn == "O" && opponent == .bot ? "Bot is thinking…" :
                 "Turn: \(turn == "X" ? "Player 1 (X)" : (opponent == .bot ? "Bot (O)" : "Player 2 (O)"))")
                 : "Result: \(winner)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    Button(board[index].isEmpty ? "·" : board[index]) { play(at: index) }
                        .font(.system(size: 26, weight: .heavy))
                        .frame(minHeight: 62)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        .disabled(!board[index].isEmpty || !winner.isEmpty ||
                                  (opponent == .bot && turn == "O"))
                }
            }
            Button("New round") { resetTic() }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func resetTic() {
        ticRoundID = UUID()
        board = Array(repeating: "", count: 9)
        turn = "X"
        winner = ""
    }

    private func submitGuess() {
        if guess == target {
            streak += 1
            best = max(best, streak)
            result = "Correct! New number chosen."
            target = Int.random(in: 1...100)
        } else { result = guess < target ? "Higher!" : "Lower!" }
    }

    private func play(at index: Int) {
        guard winner.isEmpty && board[index].isEmpty &&
              !(opponent == .bot && turn == "O") else { return }
        applyTicMove(at: index)
    }

    private func applyTicMove(at index: Int) {
        guard board[index].isEmpty, winner.isEmpty else { return }
        board[index] = turn
        if ticWinner(board) == turn {
            winner = "\(turn == "X" ? "Player 1" : (opponent == .bot ? "Bot" : "Player 2")) wins!"
        } else if !board.contains("") {
            winner = "Draw"
        } else {
            turn = turn == "X" ? "O" : "X"
            if opponent == .bot && turn == "O" {
                let round = ticRoundID
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    guard ticRoundID == round, opponent == .bot, turn == "O", winner.isEmpty else { return }
                    if let move = chooseTicBotMove() { applyTicMove(at: move) }
                }
            }
        }
    }

    private func ticWinner(_ state: [String]) -> String {
        for line in winLines where line.allSatisfy({ state[$0] == state[line[0]] && !state[$0].isEmpty }) {
            return state[line[0]]
        }
        return ""
    }

    private func chooseTicBotMove() -> Int? {
        let spaces = board.indices.filter { board[$0].isEmpty }
        guard !spaces.isEmpty else { return nil }
        if difficulty == .easy { return spaces.randomElement() }
        // Medium: immediate win or block, otherwise random.
        if difficulty == .medium {
            for symbol in ["O", "X"] {
                for i in spaces {
                    var test = board
                    test[i] = symbol
                    if ticWinner(test) == symbol { return i }
                }
            }
            return spaces.randomElement()
        }
        // Hard: optimal minimax play; never reads the user's future move.
        var bestScore = Int.min
        var bestMoves = [Int]()
        for i in spaces {
            var test = board
            test[i] = "O"
            let score = ticMinimax(test, maximizing: false, depth: 0)
            if score > bestScore { bestScore = score; bestMoves = [i] }
            else if score == bestScore { bestMoves.append(i) }
        }
        return bestMoves.randomElement()
    }

    private func ticMinimax(_ state: [String], maximizing: Bool, depth: Int) -> Int {
        let won = ticWinner(state)
        if won == "O" { return 10 - depth }
        if won == "X" { return depth - 10 }
        let spaces = state.indices.filter { state[$0].isEmpty }
        if spaces.isEmpty { return 0 }
        if maximizing {
            var best = Int.min
            for i in spaces {
                var test = state
                test[i] = "O"
                best = max(best, ticMinimax(test, maximizing: false, depth: depth + 1))
            }
            return best
        }
        var best = Int.max
        for i in spaces {
            var test = state
            test[i] = "X"
            best = min(best, ticMinimax(test, maximizing: true, depth: depth + 1))
        }
        return best
    }
}
