import AppKit
import CoreImage

/// Straightens and crops gel photos — the fix for "this photo came out a little crooked."
enum GelImageProcessor {
    private static let context = CIContext()

    /// Rotates the image by `degrees` to correct a slight tilt, auto-cropping away the
    /// resulting empty corners — Core Image's built-in filter for exactly this ("de-skew a
    /// crooked photo"), so there's no custom rotation/crop math to get subtly wrong.
    static func straighten(_ image: NSImage, degrees: Double) -> NSImage? {
        guard let ciImage = ciImage(from: image) else { return nil }
        guard degrees != 0 else { return image }
        guard let filter = CIFilter(name: "CIStraightenFilter") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(degrees * .pi / 180, forKey: kCIInputAngleKey)
        guard let output = filter.outputImage else { return image }
        return render(output)
    }

    /// Crops to a unit rect (0...1 fractions of the image's width/height, origin top-left —
    /// SwiftUI's convention, not Core Image's bottom-left one, so the Y axis is flipped here).
    static func crop(_ image: NSImage, unitRect: CGRect) -> NSImage? {
        guard let ciImage = ciImage(from: image) else { return nil }
        let extent = ciImage.extent
        let cropRect = CGRect(
            x: extent.minX + unitRect.minX * extent.width,
            y: extent.minY + (1 - unitRect.maxY) * extent.height,
            width: unitRect.width * extent.width,
            height: unitRect.height * extent.height
        )
        return render(ciImage.cropped(to: cropRect))
    }

    private static func ciImage(from image: NSImage) -> CIImage? {
        guard let tiffData = image.tiffRepresentation else { return nil }
        return CIImage(data: tiffData)
    }

    private static func render(_ ciImage: CIImage) -> NSImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
    }
}
