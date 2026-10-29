import SwiftUI

struct NativeGameView: View {
    @AppStorage("itamaros.games.bestGuessStreak") private var best = 0
    @State private var target = Int.random(in: 1...20)
    @State private var guess = 10
    @State private var streak = 0
    @State private var result = "Guess a number from 1 to 20."
    @State private var board = Array(repeating: "", count: 9)
    @State private var turn = "X"
    @State private var winner = ""
    private let winLines = [
        [0,1,2],[3,4,5],[6,7,8],
        [0,3,6],[1,4,7],[2,5,8],
        [0,4,8],[2,4,6]
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    GroupBox("Number Guess") {
                        VStack(spacing: 14) {
                            Text(result)
                            Stepper("Guess: \(guess)", value: $guess, in: 1...20)
                            Button("Submit guess") { submitGuess() }
                                .buttonStyle(.borderedProminent)
                            Text("Streak: \(streak) · Best: \(best)")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    GroupBox("Tic-Tac-Toe · 2 players") {
                        VStack(spacing: 16) {
                            Text(winner.isEmpty ? "Turn: \(turn)" : "Result: \(winner)")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(0..<9, id: \.self) { index in
                                    Button(board[index].isEmpty ? "·" : board[index]) {
                                        play(at: index)
                                    }
                                    .font(.system(size: 26, weight: .heavy))
                                    .frame(minHeight: 62)
                                    .frame(maxWidth: .infinity)
                                    .buttonStyle(.bordered)
                                    .disabled(!board[index].isEmpty || !winner.isEmpty)
                                }
                            }
                            Button("New round") {
                                board = Array(repeating: "", count: 9)
                                turn = "X"
                                winner = ""
                            }
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Games")
        }
    }

    private func submitGuess() {
        if guess == target {
            streak += 1
            best = max(best, streak)
            result = "Correct! New number chosen."
            target = Int.random(in: 1...20)
        } else {
            result = guess < target ? "Higher!" : "Lower!"
        }
    }

    private func play(at index: Int) {
        guard board[index].isEmpty, winner.isEmpty else { return }
        board[index] = turn
        if winLines.contains(where: { $0.allSatisfy { board[$0] == turn } }) {
            winner = "\(turn) wins"
        } else if !board.contains("") {
            winner = "Draw"
        } else {
            turn = turn == "X" ? "O" : "X"
        }
    }
}
