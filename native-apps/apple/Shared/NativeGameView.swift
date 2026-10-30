import SwiftUI

struct NativeGameView: View {
    @AppStorage("itamaros.games.bestGuessStreak") private var best = 0
    @State private var selectedGame = "Number Guess"
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
    private let winLines = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Text("11 offline native games").font(.headline)
                    Picker("Choose a game", selection: $selectedGame) {
                        ForEach(games, id: \.self) { title in Text(title).tag(title) }
                    }
                    .pickerStyle(.menu)
                    if selectedGame == "Number Guess" { numberGuess }
                    else if selectedGame == "Tic-Tac-Toe" { ticTacToe }
                    else { ExtraMobileGames(game: selectedGame) }
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
            HStack(spacing: 18) {
                Button("−") { guess = max(1, guess - 1) }
                Text("Guess: \(guess)").font(.title2)
                Button("+") { guess = min(100, guess + 1) }
            }
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
