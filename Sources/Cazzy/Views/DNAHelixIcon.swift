import SwiftUI

/// SF Symbols has no DNA/double-helix glyph, so this draws one. Used as a notebook icon
/// wherever `Image(systemName:)` would otherwise go — see `NotebookSymbolIcon`.
struct DNAHelixIcon: View {
    static let symbolID = "custom.dna.helix"

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                DNAStrandsShape()
                    .stroke(style: StrokeStyle(lineWidth: width * 0.035, lineCap: .round, lineJoin: .round))
                DNARungsShape()
                    .stroke(style: StrokeStyle(lineWidth: width * 0.028, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 15, height: 15)
    }
}

/// Renders any notebook symbol, transparently substituting the custom DNA icon when the
/// stored symbol string is `DNAHelixIcon.symbolID` instead of a real SF Symbol name.
struct NotebookSymbolIcon: View {
    let symbol: String

    var body: some View {
        if symbol == DNAHelixIcon.symbolID {
            DNAHelixIcon()
        } else {
            Image(systemName: symbol)
        }
    }
}

/// The two twisting strands of the helix — 1.5 sine periods top to bottom, so the strands
/// cross 3 times (a recognizable "twist" count at small sizes).
private struct DNAStrandsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = Self.insetRect(rect)
        let steps = 48
        var strandA: [CGPoint] = []
        var strandB: [CGPoint] = []
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            strandA.append(Self.point(t, phase: 0, rect: inset))
            strandB.append(Self.point(t, phase: .pi, rect: inset))
        }
        path.addLines(strandA)
        path.move(to: strandB[0])
        path.addLines(strandB)
        return path
    }

    /// 10% margin on all sides so the wave's peaks don't touch the icon's bounding box.
    static func insetRect(_ rect: CGRect) -> CGRect {
        rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.10)
    }

    static func point(_ t: CGFloat, phase: CGFloat, rect: CGRect) -> CGPoint {
        let amplitude = rect.width * 0.38
        let periods: CGFloat = 1.5
        return CGPoint(
            x: rect.midX + amplitude * sin(t * .pi * 2 * periods + phase),
            y: rect.minY + t * rect.height
        )
    }
}

/// The short cross-rungs connecting the two strands — skipped near the crossing points,
/// where the strands already meet and a rung would be zero-length.
private struct DNARungsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = DNAStrandsShape.insetRect(rect)
        let rungCount = 7
        for i in 0..<rungCount {
            let t = (CGFloat(i) + 0.5) / CGFloat(rungCount)
            let p1 = DNAStrandsShape.point(t, phase: 0, rect: inset)
            let p2 = DNAStrandsShape.point(t, phase: .pi, rect: inset)
            guard abs(p1.x - p2.x) >= inset.width * 0.18 else { continue }
            path.move(to: p1)
            path.addLine(to: p2)
        }
        return path
    }
}
