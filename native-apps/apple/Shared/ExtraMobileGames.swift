import SwiftUI

// Nine offline native SwiftUI games that complement Number Guess and Tic-Tac-Toe.
// The same source compiles on iPhone, iPad, and Mac. Apple TV uses its dedicated store UI.
struct ExtraMobileGames: View {
    let game: String

    @ViewBuilder var body: some View {
        switch game {
        case "2048": Game2048View()
        case "Snake": SnakeView()
        case "Memory Match": MemoryMatchView()
        case "Reaction Test": ReactionTestView()
        case "Rock Paper Scissors": RockPaperScissorsView()
        case "Math Sprint": MathSprintView()
        case "Word Mix": WordMixView()
        case "Pattern Memory": PatternMemoryView()
        case "Connect Four": ConnectFourView()
        default: Text("Choose a game.")
        }
    }
}

private struct Game2048View: View {
    @AppStorage("itamaros.games.2048best") private var best = 0
    @State private var board = [Int](repeating: 0, count: 16)
    @State private var score = 0

    var body: some View {
        VStack(spacing: 14) {
            Text("2048").font(.title2.bold())
            Text("Merge identical tiles. Score: \(score) · Best: \(best)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                ForEach(0..<16, id: \.self) { i in
                    Text(board[i] == 0 ? "·" : String(board[i]))
                        .font(.headline)
                        .foregroundStyle(.black.opacity(0.75))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(board[i] == 0 ? Color.gray.opacity(0.17) :
                                    [Color.yellow, Color.mint, Color.pink, Color.orange, Color.cyan, Color.purple][min(5, Int(log2(Double(max(2, board[i])))) - 1)])
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 18).onEnded { value in
                let drag = value.translation
                guard max(abs(drag.width), abs(drag.height)) > 18 else { return }
                let direction = abs(drag.width) > abs(drag.height)
                    ? (drag.width > 0 ? "→" : "←")
                    : (drag.height > 0 ? "↓" : "↑")
                move(direction)
            })
            Text("Swipe the tiles in any direction to merge them.")
                .font(.caption).foregroundStyle(.secondary)
            Button("New game") { reset() }
        }
        .onAppear { if board.allSatisfy({ $0 == 0 }) { reset() } }
    }

    private func reset() {
        board = Array(repeating: 0, count: 16)
        score = 0
        spawn()
        spawn()
    }

    private func spawn() {
        let free = board.indices.filter { board[$0] == 0 }
        if let i = free.randomElement() { board[i] = Int.random(in: 1...10) == 1 ? 4 : 2 }
    }

    private func move(_ direction: String) {
        var next = board
        var gained = 0
        for line in 0..<4 {
            let indices: [Int] = (0..<4).map { j in
                switch direction {
                case "←": return line * 4 + j
                case "→": return line * 4 + 3 - j
                case "↑": return j * 4 + line
                default: return (3 - j) * 4 + line
                }
            }
            let values = indices.map { board[$0] }.filter { $0 != 0 }
            var merged = [Int]()
            var i = 0
            while i < values.count {
                if i + 1 < values.count && values[i] == values[i+1] {
                    merged.append(values[i] * 2)
                    gained += values[i] * 2
                    i += 2
                } else {
                    merged.append(values[i])
                    i += 1
                }
            }
            for (j, idx) in indices.enumerated() { next[idx] = j < merged.count ? merged[j] : 0 }
        }
        if next != board {
            board = next
            spawn()
            score += gained
            best = max(best, score)
        }
    }
}

private struct SnakeView: View {
    @AppStorage("itamaros.games.snakebest") private var best = 0
    @State private var snake = [54,53,52]
    @State private var food = 57
    @State private var direction = 1
    @State private var running = false
    @State private var finished = false
    @State private var score = 0
    @State private var lastDrag: CGSize = .zero
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            Text("Snake").font(.title2.bold())
            Text("Score: \(score) · Best: \(best)\(finished ? " · Game over" : "")")
            VStack(spacing: 1) {
                ForEach(0..<10, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<10, id: \.self) { col in
                            let pos = row * 10 + col
                            CartoonSnakeCell(head: pos == snake.first,
                                             food: pos == food,
                                             segment: snake.contains(pos))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(6)
            .background(Color.green.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 6)
                .onChanged { value in
                    let dx = value.translation.width - lastDrag.width
                    let dy = value.translation.height - lastDrag.height
                    guard max(abs(dx), abs(dy)) >= 16 else { return }
                    let next = abs(dx) > abs(dy) ? (dx > 0 ? 1 : -1) : (dy > 0 ? 10 : -10)
                    if next != -direction { direction = next }
                    lastDrag = value.translation
                }
                .onEnded { _ in lastDrag = .zero })
            Text("Drag on the board to steer the cartoon snake toward the cherries.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(running ? "Pause" : "Start") { if !finished { running.toggle() } }
                Button("Restart") { reset() }
            }
        }
        .onReceive(timer) { _ in if running { tick() } }
    }

    private func reset() {
        snake = [54,53,52]; food = 57; direction = 1; running = false; finished = false; score = 0
    }

    private func tick() {
        guard let head = snake.first else { return }
        let next = head + direction
        if next < 0 || next >= 100 || (direction == 1 && head % 10 == 9)
            || (direction == -1 && head % 10 == 0)
            || (snake.dropLast(next == food ? 0 : 1)).contains(next) {
            running = false; finished = true; return
        }
        snake.insert(next, at: 0)
        if next == food {
            score += 1; best = max(best, score)
            let empty = Array(0..<100).filter { !snake.contains($0) }
            if let pick = empty.randomElement() { food = pick }
            else { running = false; finished = true }
        } else { snake.removeLast() }
    }
}

private struct MemoryMatchView: View {
    @AppStorage("itamaros.games.memorybest") private var best = 0
    private let symbols = ["🍀","⭐","🎯","🎵","🐱","🚀","🌈","🍎"]
    @State private var cards = [String]()
    @State private var visible = [Int]()
    @State private var matched = Set<Int>()
    @State private var moves = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Memory Match").font(.title2.bold())
            Text("Moves: \(moves) · Best completed: \(best == 0 ? "—" : String(best))")
            if matched.count == 16 { Text("All pairs found!") }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                ForEach(0..<cards.count, id: \.self) { i in
                    Button(matched.contains(i) || visible.contains(i) ? cards[i] : "❔") { select(i) }
                        .frame(minHeight: 56)
                        .buttonStyle(.bordered)
                        .disabled(matched.contains(i) || visible.count >= 2)
                }
            }
            Button("New cards") { reset() }
        }
        .onAppear { if cards.isEmpty { reset() } }
    }

    private func reset() {
        cards = (symbols + symbols).shuffled(); matched = []; visible = []; moves = 0
    }

    private func select(_ index: Int) {
        guard !matched.contains(index), !visible.contains(index), visible.count < 2 else { return }
        visible.append(index)
        if visible.count == 2 {
            moves += 1
            let a = visible[0], b = visible[1], snapshot = cards
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard snapshot == cards else { return }
                if cards[a] == cards[b] {
                    matched.insert(a); matched.insert(b)
                    if matched.count == 16 && (best == 0 || moves < best) { best = moves }
                }
                visible = []
            }
        }
    }
}

private struct ReactionTestView: View {
    @AppStorage("itamaros.games.reactionbest") private var best = 0
    @State private var phase = 0
    @State private var start = Date()
    @State private var result = ""

    var body: some View {
        VStack(spacing: 14) {
            Text("Reaction Test").font(.title2.bold())
            Text(phase == 1 ? "Wait for GO!" : phase == 2 ? "GO! TAP NOW" : "Tap Start to begin.")
            Button(phase == 0 ? "Start" : phase == 1 ? "Too soon? Reset" : "TAP!") { tap() }
                .buttonStyle(.borderedProminent)
            Text(result)
            Text("Best reaction: \(best == 0 ? "—" : "\(best) ms")")
        }
    }

    private func tap() {
        if phase == 0 {
            phase = 1; result = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.4...3.3)) {
                if phase == 1 { start = Date(); phase = 2 }
            }
        } else if phase == 1 { phase = 0; result = "Too early. Try again." }
        else {
            let ms = max(1, Int(Date().timeIntervalSince(start) * 1000))
            best = best == 0 ? ms : min(best, ms)
            result = "Your reaction: \(ms) ms"; phase = 0
        }
    }
}

private struct RockPaperScissorsView: View {
    @AppStorage("itamaros.games.rpsbest") private var best = 0
    @State private var wins = 0
    @State private var result = "Choose a move."
    private let choices = ["Rock","Paper","Scissors"]

    var body: some View {
        VStack(spacing: 14) {
            Text("Rock Paper Scissors").font(.title2.bold())
            HStack {
                ForEach(choices.indices, id: \.self) { index in
                    Button(choices[index]) { play(index) }.buttonStyle(.borderedProminent)
                }
            }
            Text(result)
            Text("Wins: \(wins) · Best: \(best)")
        }
    }

    private func play(_ mine: Int) {
        let other = Int.random(in: 0...2)
        if mine == other { result = "Draw! The device chose \(choices[other])." }
        else if (mine - other + 3) % 3 == 1 {
            wins += 1; best = max(best, wins)
            result = "You win! The device chose \(choices[other])."
        } else { result = "The device wins with \(choices[other])." }
    }
}

private struct MathSprintView: View {
    @AppStorage("itamaros.games.mathbest") private var best = 0
    @State private var first = Int.random(in: 2...30)
    @State private var second = Int.random(in: 1...20)
    @State private var answer = ""
    @State private var total = 0
    @State private var message = "Solve the sum."

    var body: some View {
        VStack(spacing: 12) {
            Text("Math Sprint").font(.title2.bold())
            Text("\(first) + \(second) = ?").font(.largeTitle)
            TextField("Your answer", text: $answer)
            Button("Submit") {
                if Int(answer) == first + second { total += 1; best = max(best, total); message = "Correct!" }
                else { message = "Next question." }
                first = Int.random(in: 2...30); second = Int.random(in: 1...20); answer = ""
            }
            Text("\(message) · Correct: \(total) · Best: \(best)")
        }
    }
}

private struct WordMixView: View {
    @AppStorage("itamaros.games.wordbest") private var best = 0
    private let words = ["planet","rocket","galaxy","puzzle","winter","island","orange","camera","jungle"]
    @State private var current = "planet"
    @State private var mixed = "tnealp"
    @State private var answer = ""
    @State private var solved = 0
    @State private var message = "Unscramble the word."

    var body: some View {
        VStack(spacing: 12) {
            Text("Word Mix").font(.title2.bold())
            Text(mixed).font(.title.bold())
            TextField("English word", text: $answer)
            Button("Check") {
                if answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == current {
                    solved += 1; best = max(best, solved); message = "Correct!"; next()
                } else { message = "Try again." }
            }
            Text("\(message) · Solved: \(solved) · Best: \(best)")
        }
        .onAppear { if solved == 0 { next() } }
    }

    private func next() {
        current = words.randomElement() ?? "planet"
        mixed = String(current.shuffled())
        answer = ""
    }
}

private struct PatternMemoryView: View {
    @AppStorage("itamaros.games.patternbest") private var best = 0
    @State private var pattern = [Int.random(in: 0...3)]
    @State private var position = 0
    @State private var showing = true
    @State private var message = "Memorize the sequence."
    private let choices = ["🔴","🔵","🟡","🟢"]

    var body: some View {
        VStack(spacing: 12) {
            Text("Pattern Memory").font(.title2.bold())
            Text("Level \(pattern.count) · Best \(best)")
            Text(showing ? pattern.map { choices[$0] }.joined(separator: " ") : "Your turn!")
                .font(.title2)
            HStack {
                ForEach(0..<4, id: \.self) { i in
                    Button(choices[i]) { pick(i) }.disabled(showing)
                }
            }
            Text(message)
            Button("Restart") { pattern = [Int.random(in: 0...3)]; position = 0; reveal() }
        }
        .onAppear { reveal() }
    }

    private func reveal() {
        showing = true
        let snapshot = pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7 + Double(pattern.count) * 0.5) {
            if snapshot == pattern { showing = false }
        }
    }

    private func pick(_ chosen: Int) {
        guard !showing else { return }
        if pattern[position] != chosen {
            message = "Try a new sequence."
            pattern = [Int.random(in: 0...3)]; position = 0; reveal()
        } else {
            position += 1
            if position == pattern.count {
                best = max(best, pattern.count)
                pattern.append(Int.random(in: 0...3))
                position = 0; message = "Correct! Next level."; reveal()
            }
        }
    }
}

private struct ConnectFourView: View {
    @State private var board = [Int](repeating: 0, count: 42)
    @State private var player = 1
    @State private var winner = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Connect Four · 2 players").font(.title2.bold())
            Text(winner.isEmpty ? "Player \(player)'s turn" : winner)
            Text("Drag a disc to a column or tap the board to drop it.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Circle().fill(player == 1 ? Color.red.gradient : Color.yellow.gradient)
                    .frame(width: 36, height: 36)
                Text("Player \(player) disc").font(.subheadline.bold())
            }
            GeometryReader { geometry in
                VStack(spacing: 3) {
                    ForEach(0..<6, id: \.self) { row in
                        HStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { col in
                                Circle()
                                    .fill(board[row*7+col] == 1 ? Color.red.gradient :
                                          board[row*7+col] == 2 ? Color.yellow.gradient :
                                          Color.white.gradient)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .accessibilityLabel("Column \(col + 1), row \(row + 1)")
                            }
                        }
                    }
                }
                .padding(7)
                .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    let width = max(1, geometry.size.width)
                    let column = min(6, max(0, Int(value.location.x / width * 7)))
                    drop(column)
                })
            }
            .frame(height: 220)
            Button("New round") { board = Array(repeating: 0, count: 42); player = 1; winner = "" }
        }
    }

    private func drop(_ col: Int) {
        guard winner.isEmpty else { return }
        guard let row = (0..<6).reversed().first(where: { board[$0*7+col] == 0 }) else { return }
        board[row*7+col] = player
        for r in 0..<6 {
            for c in 0..<7 where board[r*7+c] == player {
                for (dc,dr) in [(1,0),(0,1),(1,1),(-1,1)] {
                    if (0..<4).allSatisfy({ t in
                        let x = c + dc*t, y = r + dr*t
                        return x >= 0 && x < 7 && y >= 0 && y < 6 && board[y*7+x] == player
                    }) { winner = "Player \(player) wins!" }
                }
            }
        }
        if winner.isEmpty { winner = board.allSatisfy { $0 != 0 } ? "Draw" : "" }
        if winner.isEmpty { player = 3-player }
    }
}
