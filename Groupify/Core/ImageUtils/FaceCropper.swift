import CoreGraphics
import UIKit

/// Crops a face region from a UIImage, correctly handling EXIF orientation.
///
/// The bounding box must be in normalized coordinates (0...1) with
/// **top-left origin** (as returned by `VisionFaceDetector`).
enum FaceCropper {
    nonisolated static let paddingFraction: CGFloat = 0.15

    nonisolated static func crop(
        from image: UIImage,
        boundingBox box: FaceBoundingBox
    ) -> CGImage? {
        // 1. Render UIImage into a CGContext to normalize EXIF orientation.
        //    UIImage.draw(in:) applies the orientation transform automatically.
        let scale = image.scale
        let bitmapWidth  = Int(image.size.width * scale)
        let bitmapHeight = Int(image.size.height * scale)
        guard bitmapWidth > 0, bitmapHeight > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: bitmapWidth,
            height: bitmapHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(x: 0, y: 0, width: bitmapWidth, height: bitmapHeight))
        UIGraphicsPopContext()

        guard let straightCG = ctx.makeImage() else { return nil }

        // 2. Convert normalized top-left coords to pixel coords.
        let px = CGFloat(box.x) * CGFloat(bitmapWidth)
        let py = CGFloat(box.y) * CGFloat(bitmapHeight)
        let pw = CGFloat(box.width) * CGFloat(bitmapWidth)
        let ph = CGFloat(box.height) * CGFloat(bitmapHeight)

        // 3. Add padding.
        let pad = paddingFraction * max(pw, ph)
        let x0 = max(0, px - pad)
        let y0 = max(0, py - pad)
        let x1 = min(CGFloat(bitmapWidth), px + pw + pad)
        let y1 = min(CGFloat(bitmapHeight), py + ph + pad)

        let cropRect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        guard cropRect.width > 0, cropRect.height > 0 else { return nil }

        return straightCG.cropping(to: cropRect)
    }
}
