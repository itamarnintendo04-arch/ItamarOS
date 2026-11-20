#if os(iOS)
import SwiftUI
import UIKit

/// In-app icon picker. The alternate icons must be compiled into the target's
/// asset catalog via ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
struct ChangeAppIconView: View {
    @State private var current = UIApplication.shared.alternateIconName
    @State private var changing = false
    @State private var changeError: String?

    private struct Option: Identifiable {
        let id: String
        let title: String
        let assetName: String?
        let previewName: String
    }

    private let options: [Option] = [
        .init(id: "original", title: "Original", assetName: nil, previewName: "ItamarIconPreviewOriginal"),
        .init(id: "blue", title: "Rainbow Glitch", assetName: "ItamarIconBlue", previewName: "ItamarIconPreviewBlue"),
        .init(id: "green", title: "Prism Shift", assetName: "ItamarIconGreen", previewName: "ItamarIconPreviewGreen"),
        .init(id: "purple", title: "RGB Split", assetName: "ItamarIconPurple", previewName: "ItamarIconPreviewPurple"),
        .init(id: "pink", title: "Holographic", assetName: "ItamarIconPink", previewName: "ItamarIconPreviewPink"),
        .init(id: "orange", title: "Liquid Spectrum", assetName: "ItamarIconOrange", previewName: "ItamarIconPreviewOrange"),
        .init(id: "red", title: "Neon Noise", assetName: "ItamarIconRed", previewName: "ItamarIconPreviewRed")
    ]

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12),
         GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose a multicolor glitch version of the original logo. Each icon blends multiple rainbow colors with RGB distortion, prismatic light and holographic effects.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(options) { option in
                        let isSelected = current == option.assetName
                        Button {
                            change(to: option.assetName)
                        } label: {
                            VStack(spacing: 9) {
                                Image(option.previewName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white, .blue)
                                                .padding(4)
                                        }
                                    }
                                Text(option.title)
                                    .font(.caption.weight(isSelected ? .bold : .regular))
                                    .foregroundStyle(.primary)
                                if isSelected {
                                    Text("Selected")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .buttonStyle(.plain)
                        .disabled(changing || isSelected)
                        .accessibilityLabel(option.title + (isSelected ? ", selected" : ""))
                    }
                }
                if changing {
                    ProgressView("Updating Home Screen icon…")
                }
                if !UIApplication.shared.supportsAlternateIcons {
                    Label("Alternate icons are unavailable in this installation.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
                Text("iOS may show a system confirmation when you change your app icon. You can restore the original icon at any time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Change App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { current = UIApplication.shared.alternateIconName }
        .alert("Unable to change icon",
               isPresented: Binding(get: { changeError != nil }, set: { if !$0 { changeError = nil } })) {
            Button("OK") { changeError = nil }
        } message: {
            Text(changeError ?? "")
        }
    }

    private func change(to iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            changeError = "This version does not support alternate app icons. Install a build that includes the icon packs."
            return
        }
        changing = true
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                changing = false
                if let error {
                    changeError = error.localizedDescription
                } else {
                    current = UIApplication.shared.alternateIconName
                }
            }
        }
    }
}
#endif
