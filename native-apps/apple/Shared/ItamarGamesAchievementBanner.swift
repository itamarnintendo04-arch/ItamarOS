#if os(iOS)
import SwiftUI

/// Reusable compact in-game achievement notification.
/// Games should show this only after their achievement service confirms unlock.
struct ItamarGamesAchievementBanner: View {
    let title: String
    let task: String

    var body: some View {
        HStack(spacing:12) {
            Image(systemName:"trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment:.leading,spacing:3) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text(task)
                    .font(.caption)
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            Spacer(minLength:0)
            Image(systemName:"checkmark.seal.fill")
                .foregroundStyle(.mint)
        }
        .padding(.horizontal,16)
        .padding(.vertical,11)
        .frame(maxWidth:420)
        .background(.black.opacity(0.84),in:RoundedRectangle(cornerRadius:15))
        .overlay(RoundedRectangle(cornerRadius:15)
            .stroke(.yellow.opacity(0.7),lineWidth:1))
        .shadow(radius:8)
        .accessibilityElement(children:.combine)
        .accessibilityLabel("Achievement unlocked: \(title). \(task)")
    }
}
#endif
