#if os(iOS) || os(macOS)
import SwiftUI
import ImageIO

/// Animates the actual frames of a GIF; ordinary SwiftUI Image(data:) is static.
/// Content stays on-device and requires no remote requests.
#if os(iOS)
import UIKit
struct AnimatedGIFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        let count = min(250, CGImageSourceGetCount(source))
        guard count > 0 else { return }
        var images = [UIImage]()
        var duration = 0.0
        for i in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue ?? 0.1
            let time = max(0.02, delay)
            // UIKit animationImages uses equal frame periods. Replicate small delays
            // for a reasonable approximation without generating excessive frames.
            let repeats = min(12, max(1, Int((time / 0.05).rounded())))
            for _ in 0..<repeats { images.append(UIImage(cgImage: frame)) }
            duration += Double(repeats) * 0.05
        }
        guard !images.isEmpty else { return }
        view.stopAnimating()
        view.animationImages = images
        view.animationDuration = duration
        view.animationRepeatCount = 0
        view.image = images.first
        if images.count > 1 { view.startAnimating() }
    }
}
#elseif os(macOS)
import AppKit
struct AnimatedGIFView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.animates = true
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.image = NSImage(data: data)
        view.animates = true
    }
}
#endif
#endif
