import SwiftUI
import AppKit

/// Plain, black-on-white layout used for both printing and "Save as PDF" (via the system
/// print panel) — deliberately ignores the app's theme so printed output stays legible
/// regardless of which Cazzy theme is active.
struct ProtocolPrintView: View {
    let protocolItem: LabProtocol
    let contentWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            titleBlock
            if !protocolItem.purpose.isEmpty {
                Text(protocolItem.purpose)
                    .font(.system(size: 12))
            }
            if !protocolItem.reagents.isEmpty {
                materialsSection
            }
            if !protocolItem.steps.isEmpty {
                stepsSection
            }
        }
        .foregroundStyle(Color.black)
        .padding(36)
        .frame(width: contentWidth, alignment: .leading)
        .background(Color.white)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(protocolItem.name.isEmpty ? "Untitled Protocol" : protocolItem.name)
                .font(.system(size: 22, weight: .bold))
            HStack(spacing: 10) {
                if protocolItem.currentVersionNumber > 0 {
                    Text("Version \(protocolItem.currentVersionNumber)")
                }
                Text(protocolItem.updatedAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.gray)
        }
    }

    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Materials & Reagents")
                .font(.system(size: 14, weight: .semibold))
            VStack(spacing: 0) {
                ForEach(protocolItem.reagents) { reagent in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(reagent.name)
                                .frame(width: 160, alignment: .leading)
                            Text([reagent.amount, reagent.unit].filter { !$0.isEmpty }.joined(separator: " "))
                                .frame(width: 100, alignment: .leading)
                            Text(reagent.notes)
                                .foregroundStyle(Color.gray)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 11))
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Procedure")
                .font(.system(size: 14, weight: .semibold))
            ForEach(Array(protocolItem.steps.enumerated()), id: \.element.id) { index, step in
                let ordinal = protocolItem.steps[...index].filter { $0.kind == .step }.count
                switch step.kind {
                case .step:
                    stepRow(ordinal: ordinal, step: step)
                case .note, .warning:
                    calloutRow(step: step)
                }
            }
        }
    }

    private func stepRow(ordinal: Int, step: ProtocolStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(ordinal).")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 20, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.text)
                    .font(.system(size: 12))
                let badges = stepBadges(step)
                if !badges.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(badges.enumerated()), id: \.offset) { i, badge in
                            if i > 0 {
                                Text("·").foregroundStyle(Color.gray)
                            }
                            Text(badge.text)
                                .foregroundStyle(badge.color)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                }
                if !step.notes.isEmpty {
                    Text(step.notes)
                        .font(.system(size: 10))
                        .italic()
                        .foregroundStyle(Color.gray)
                }
            }
        }
    }

    /// A "not really a step" callout — no number, colored bar + tinted background so it
    /// still catches the eye on a printed, black-and-white-otherwise page.
    private func calloutRow(step: ProtocolStep) -> some View {
        let color: Color = step.kind == .warning ? .orange : .blue
        let label = step.kind == .warning ? "WARNING" : "NOTE"
        return HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(color)
                    .tracking(0.5)
                Text(step.text)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            Spacer(minLength: 0)
        }
        .background(color.opacity(0.08))
    }

    private struct Badge {
        let text: String
        let color: Color
    }

    private func stepBadges(_ step: ProtocolStep) -> [Badge] {
        var badges: [Badge] = []
        if let duration = step.durationMinutes {
            badges.append(Badge(text: formattedDuration(duration), color: .gray))
        }
        if let temperature = step.temperatureCelsius {
            badges.append(Badge(text: "\(String(format: "%g", temperature))°C", color: .gray))
        }
        switch step.importance {
        case .normal: break
        case .important: badges.append(Badge(text: "IMPORTANT", color: .orange))
        case .critical: badges.append(Badge(text: "CRITICAL", color: .red))
        }
        return badges
    }

    private func formattedDuration(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours) hr \(minutes) min" }
        if hours > 0 { return "\(hours) hr" }
        return "\(minutes) min"
    }
}

/// An `NSHostingView` that paginates its (much taller than one page) SwiftUI content across
/// multiple printed pages. Plain `NSHostingView` does not do this on its own — a tall view is
/// simply clipped to a single page — so page slicing is implemented explicitly here.
private final class PaginatedHostingView<Content: View>: NSHostingView<Content> {
    var pageContentHeight: CGFloat = 700

    // NSHostingView already overrides `isFlipped` (final, returns true) to match SwiftUI's
    // top-left-origin coordinate space, so page rects below are computed top-down without
    // needing to override it here.

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        let pageCount = max(1, Int(ceil(frame.height / pageContentHeight)))
        range.pointee = NSRange(location: 1, length: pageCount)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        let pageIndex = CGFloat(page - 1)
        let y = pageIndex * pageContentHeight
        let height = min(pageContentHeight, max(0, frame.height - y))
        return NSRect(x: 0, y: y, width: frame.width, height: height)
    }
}

enum ProtocolPrinter {
    static func print(_ protocolItem: LabProtocol) {
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        let pageContentWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let pageContentHeight = printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin

        let content = ProtocolPrintView(protocolItem: protocolItem, contentWidth: pageContentWidth)
        let hostingView = PaginatedHostingView(rootView: content)
        hostingView.pageContentHeight = pageContentHeight
        hostingView.frame = CGRect(origin: .zero, size: hostingView.fittingSize)

        let operation = NSPrintOperation(view: hostingView, printInfo: printInfo)
        operation.printPanel.options.insert(.showsPaperSize)
        operation.printPanel.options.insert(.showsOrientation)
        operation.run()
    }
}
