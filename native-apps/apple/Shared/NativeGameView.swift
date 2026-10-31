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
            Slider(value: Binding(
                get: { Double(guess) },
                set: { guess = min(100, max(1, Int($0.rounded()))) }
            ), in: 1...100, step: 1)
                .accessibilityLabel("Slide to choose a number")
            Button("Submit guess") { submitGuess() }.buttonStyle(.borderedProminent)
            Text("Streak: \(streak) · Best: \(best)").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var ticTacToe: some View {
        VStack(spacing: 16) {
            Text("Tic-Tac-Toe · 2 players").font(.title2.bold())
            Text(winner.isEmpty ? "Turn: \(turn)" : "Result: \(winner)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    Button(board[index].isEmpty ? "·" : board[index]) { play(at: index) }
                        .font(.system(size: 26, weight: .heavy))
                        .frame(minHeight: 62)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        .disabled(!board[index].isEmpty || !winner.isEmpty)
                }
            }
            Button("New round") {
                board = Array(repeating: "", count: 9); turn = "X"; winner = ""
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        guard board[index].isEmpty, winner.isEmpty else { return }
        board[index] = turn
        if winLines.contains(where: { $0.allSatisfy { board[$0] == turn } }) {
            winner = "\(turn) wins"
        } else if !board.contains("") { winner = "Draw" }
        else { turn = turn == "X" ? "O" : "X" }
    }
}
