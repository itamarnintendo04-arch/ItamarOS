#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Bounded, on-device playback for animated GIF files. ImageIO handles frames;
/// no server, JavaScript or tracking views are needed.
private enum GIFFrames {
    static let maxBytes = 18 * 1024 * 1024
    static let maxFrames = 120
    static let maxPixels = 1_500_000

    static func decode(_ data: Data) -> (images: [CGImage], duration: TimeInterval)? {
        guard data.count <= maxBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) == UTType.gif.identifier as CFString else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0, frameCount <= maxFrames else { return nil }
        var images = [CGImage]()
        var total: TimeInterval = 0
        for index in 0..<frameCount {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil),
                  frame.width * frame.height <= maxPixels else { return nil }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let seconds = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            total += min(1.0, max(0.06, seconds))
            images.append(frame)
        }
        return (images, max(0.1, total))
    }
}

#if os(macOS)
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
#else
struct AnimatedGIFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Animated GIF"
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        guard let gif = GIFFrames.decode(data) else {
            view.stopAnimating()
            view.animationImages = nil
            view.image = UIImage(data: data)
            return
        }
        let frames = gif.images.map { UIImage(cgImage: $0) }
        view.animationImages = frames
        view.animationDuration = gif.duration
        view.animationRepeatCount = 0
        view.image = frames.first
        view.startAnimating()
    }
}
#endif
#endif
