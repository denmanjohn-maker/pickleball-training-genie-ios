import UIKit

extension UIImage {
    /// Scales the image down so its longest side is at most `maxDimension` points,
    /// preserving aspect ratio. Returns self if already small enough.
    func resized(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// JPEG data for an avatar upload: capped at 512px and 80% quality (~60–120 KB).
    func avatarJPEGData() -> Data? {
        resized(maxDimension: 512).jpegData(compressionQuality: 0.8)
    }
}
