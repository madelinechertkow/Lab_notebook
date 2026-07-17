import SwiftUI
import AppKit

/// Straighten (rotate) and crop a gel photo. Produces a brand new image file — never
/// overwrites the original — so re-adjusting doesn't compound on already-processed pixels.
struct GelImageAdjustSheet: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    let imageFileName: String
    var onApply: (String) -> Void

    @State private var rotationDegrees: Double = 0
    @State private var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var originalImage: NSImage?
    @State private var previewImage: NSImage?
    @State private var isApplying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adjust Gel Image")
                .font(theme.displayFont(16))
                .foregroundStyle(theme.textPrimary)

            Text("Straighten a crooked photo, then drag the handles to crop. This replaces the photo — if you've already placed lane or ladder labels, you may need to reposition them afterward.")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let previewImage {
                let aspect = previewImage.size.height > 0 ? previewImage.size.width / previewImage.size.height : 1
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Image(nsImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                        CropOverlay(cropRect: $cropRect, size: geo.size)
                    }
                }
                .aspectRatio(aspect, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 320)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Rotation: \(Int(rotationDegrees))°")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                Slider(value: $rotationDegrees, in: -45...45, step: 1)
                    .onChange(of: rotationDegrees) { _ in
                        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                        recomputePreview()
                    }
            }

            HStack {
                Button("Reset Crop") { cropRect = CGRect(x: 0, y: 0, width: 1, height: 1) }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Apply") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(previewImage == nil || isApplying)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(theme.background)
        .onAppear {
            originalImage = GelImageStore.loadImage(imageFileName)
            recomputePreview()
        }
    }

    private func recomputePreview() {
        guard let originalImage else { return }
        previewImage = GelImageProcessor.straighten(originalImage, degrees: rotationDegrees) ?? originalImage
    }

    private func apply() {
        guard let previewImage else { return }
        isApplying = true
        guard let cropped = GelImageProcessor.crop(previewImage, unitRect: cropRect),
              let newFilename = try? GelImageStore.saveProcessedImage(cropped) else {
            isApplying = false
            return
        }
        onApply(newFilename)
        dismiss()
    }
}

/// A crop rectangle with four independently draggable edge handles — dragging one edge
/// only moves that edge, so the rect stays axis-aligned without needing corner-drag math.
private struct CropOverlay: View {
    @Binding var cropRect: CGRect
    let size: CGSize
    private let minSize: CGFloat = 0.08

    var body: some View {
        let rect = CGRect(
            x: cropRect.minX * size.width,
            y: cropRect.minY * size.height,
            width: cropRect.width * size.width,
            height: cropRect.height * size.height
        )

        ZStack {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
                path.addRect(rect)
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))

            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            edgeHandle(at: CGPoint(x: rect.midX, y: rect.minY), size: CGSize(width: 44, height: 10)) { location in
                setTop(location.y / size.height)
            }
            edgeHandle(at: CGPoint(x: rect.midX, y: rect.maxY), size: CGSize(width: 44, height: 10)) { location in
                setBottom(location.y / size.height)
            }
            edgeHandle(at: CGPoint(x: rect.minX, y: rect.midY), size: CGSize(width: 10, height: 44)) { location in
                setLeading(location.x / size.width)
            }
            edgeHandle(at: CGPoint(x: rect.maxX, y: rect.midY), size: CGSize(width: 10, height: 44)) { location in
                setTrailing(location.x / size.width)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .coordinateSpace(name: "cropCanvas")
    }

    private func edgeHandle(at point: CGPoint, size handleSize: CGSize, onDrag: @escaping (CGPoint) -> Void) -> some View {
        Capsule()
            .fill(Color.white)
            .overlay(Capsule().stroke(Color.black.opacity(0.3), lineWidth: 1))
            .frame(width: handleSize.width, height: handleSize.height)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("cropCanvas"))
                    .onChanged { value in onDrag(value.location) }
            )
    }

    private func setTop(_ fraction: CGFloat) {
        let newMinY = min(max(fraction, 0), cropRect.maxY - minSize)
        cropRect = CGRect(x: cropRect.minX, y: newMinY, width: cropRect.width, height: cropRect.maxY - newMinY)
    }

    private func setBottom(_ fraction: CGFloat) {
        let newMaxY = max(min(fraction, 1), cropRect.minY + minSize)
        cropRect = CGRect(x: cropRect.minX, y: cropRect.minY, width: cropRect.width, height: newMaxY - cropRect.minY)
    }

    private func setLeading(_ fraction: CGFloat) {
        let newMinX = min(max(fraction, 0), cropRect.maxX - minSize)
        cropRect = CGRect(x: newMinX, y: cropRect.minY, width: cropRect.maxX - newMinX, height: cropRect.height)
    }

    private func setTrailing(_ fraction: CGFloat) {
        let newMaxX = max(min(fraction, 1), cropRect.minX + minSize)
        cropRect = CGRect(x: cropRect.minX, y: cropRect.minY, width: newMaxX - cropRect.minX, height: cropRect.height)
    }
}
