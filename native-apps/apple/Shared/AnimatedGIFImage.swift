#if os(iOS)
import SwiftUI
import UIKit
import ImageIO

/// Animated GIF decoder for the ItamarOS Player.
/// Limits decoded pixels and frames to avoid unbounded memory use on iPhone.
struct AnimatedGIFImage: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.accessibilityLabel = "Animated GIF"
        view.image = Self.decode(data)
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // The view identity is recreated when a different file is selected.
        if uiView.image == nil {
            uiView.image = Self.decode(data)
            uiView.startAnimating()
        }
    }

    static func decode(_ data: Data) -> UIImage? {
        guard data.count <= 24 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            return UIImage(data: data)
        }

        let count = min(CGImageSourceGetCount(source), 150)
        var frames: [UIImage] = []
        var duration = 0.0
        var pixels = 0
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            pixels += image.width * image.height
            guard pixels <= 100_000_000 else { break }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
            let unclamped = gif?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
            let delay = gif?[kCGImagePropertyGIFDelayTime as String] as? Double
            let seconds = max(0.04, unclamped ?? delay ?? 0.1)
            // UIImage's animatedImage uses equal frame times. Approximate delay
            // with repetition while limiting total decoded display frames.
            let repeatCount = min(8, max(1, Int((seconds / 0.06).rounded())))
            let frame = UIImage(cgImage: image)
            for _ in 0..<repeatCount { frames.append(frame) }
            duration += seconds
        }
        guard !frames.isEmpty else { return UIImage(data: data) }
        if frames.count == 1 { return frames[0] }
        // Playback loops using UIKit without requiring an external GIF server.
        return UIImage.animatedImage(with: frames, duration: max(0.1, duration))
    }
}
#endif
