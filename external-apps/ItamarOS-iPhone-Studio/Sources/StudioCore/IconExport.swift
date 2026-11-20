import Foundation
import UIKit

public enum IconExport {
    public static func png(from image: UIImage) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024))
        let output = renderer.image { _ in
            UIColor.systemBackground.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
            let size = image.size
            guard size.width > 0 && size.height > 0 else { return }
            let scale = max(1024 / size.width, 1024 / size.height)
            let width = size.width * scale
            let height = size.height * scale
            image.draw(in: CGRect(x: (1024-width)/2, y: (1024-height)/2, width: width, height: height))
        }
        return output.pngData()
    }
}
