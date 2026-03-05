import CoreGraphics
import UIKit

/// Renders a UIImage into a new upright CGImage with orientation = .up,
/// stripping any EXIF orientation metadata. This is the single source of
/// truth for both Vision detection and face cropping.
enum ImageNormalizer {

    struct NormalizedImage: Sendable {
        let cgImage: CGImage
        let size: CGSize  // pixel dimensions of the upright image
    }

    /// Returns an upright CGImage by re-drawing the UIImage into a bitmap context.
    /// If `maxDimension` is provided the image is downscaled (keeping aspect ratio)
    /// so the largest side ≤ maxDimension — useful for preserving small faces.
    nonisolated static func normalizeUpright(
        from uiImage: UIImage,
        maxDimension: CGFloat? = nil
    ) -> NormalizedImage? {
        let scale = uiImage.scale
        var pixelWidth  = uiImage.size.width * scale
        var pixelHeight = uiImage.size.height * scale
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        // Optional downscale.
        if let maxDim = maxDimension {
            let longest = max(pixelWidth, pixelHeight)
            if longest > maxDim {
                let ratio = maxDim / longest
                pixelWidth  = (pixelWidth * ratio).rounded(.down)
                pixelHeight = (pixelHeight * ratio).rounded(.down)
            }
        }

        let w = Int(pixelWidth)
        let h = Int(pixelHeight)
        guard w > 0, h > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // CGContext uses bottom-left origin, but UIImage.draw uses top-left
        // (UIKit coordinates). Flip the context so UIImage.draw renders
        // right-side-up in the resulting CGImage.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)

        // UIImage.draw applies the EXIF orientation transform automatically,
        // producing a truly upright raster in the now-flipped context.
        UIGraphicsPushContext(ctx)
        uiImage.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        UIGraphicsPopContext()

        guard let cgImage = ctx.makeImage() else { return nil }
        return NormalizedImage(cgImage: cgImage, size: CGSize(width: w, height: h))
    }
}
