import SwiftUI

@main
struct ItamarOSWatch: App {
    var body: some Scene {
        WindowGroup { WatchHome() }
    }
}

struct WatchHome: View {
    @AppStorage("itamaros.watch.best") private var best = 0
    @State private var target = Int.random(in: 1...10)
    @State private var guess = 5
    @State private var status = "Guess 1–10"
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image("BrandMark").resizable().scaledToFit().frame(width: 65, height: 65)
                Text("ItamarOS").font(.headline)
                Text("Native watch app · 1.1").font(.caption2)
                Text(status)
                Stepper("Guess \(guess)", value: $guess, in: 1...10)
                Button("Guess") {
                    if guess == target {
                        best += 1
                        status = "Correct!"
                        target = Int.random(in: 1...10)
                    } else {
                        status = guess < target ? "Higher!" : "Lower!"
                    }
                }
                Text("Best correct guesses: \(best)").font(.caption)
                Text("Local watch data. No OS replacement.").font(.caption2)
            }
            .padding(8)
        }
    }
}
