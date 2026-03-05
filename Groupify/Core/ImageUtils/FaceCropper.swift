import CoreGraphics
import UIKit

/// Crops a face region from a UIImage using the same upright bitmap that
/// `VisionFaceDetector` uses for detection, guaranteeing coordinate alignment.
///
/// The bounding box must be in normalized coordinates (0...1) with
/// **top-left origin** (as returned by `VisionFaceDetector`).
enum FaceCropper {
    nonisolated static let paddingFraction: CGFloat = 0.15

    /// Crops a face from the UIImage. Uses `ImageNormalizer` to produce the
    /// same upright CGImage that Vision ran on, ensuring bbox alignment.
    nonisolated static func crop(
        from image: UIImage,
        boundingBox box: FaceBoundingBox
    ) -> CGImage? {
        // 1. Normalize to the same upright bitmap used for detection.
        guard let normalized = ImageNormalizer.normalizeUpright(from: image) else {
            return nil
        }
        let uprightCG = normalized.cgImage
        let w = CGFloat(normalized.size.width)
        let h = CGFloat(normalized.size.height)

        // 2. Convert normalized top-left coords to pixel coords.
        let px = CGFloat(box.x) * w
        let py = CGFloat(box.y) * h
        let pw = CGFloat(box.width) * w
        let ph = CGFloat(box.height) * h

        // 3. Add padding and clamp to image bounds.
        let pad = paddingFraction * max(pw, ph)
        let x0 = max(0, px - pad)
        let y0 = max(0, py - pad)
        let x1 = min(w, px + pw + pad)
        let y1 = min(h, py + ph + pad)

        let cropRect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0).integral
        guard cropRect.width > 0, cropRect.height > 0 else { return nil }

        return uprightCG.cropping(to: cropRect)
    }
}
