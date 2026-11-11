import SwiftUI
import AppKit
import PDFKit

// Printing and PDF export of a protocol, laid out like View mode (headings, buffer cards,
// numbered step cards, colored callouts) but always black-on-white so it stays legible
// whatever Cazzy theme is active. Each tick box is an empty circle to mark with a pen.
//
// The protocol is drawn into a real PDF (via ImageRenderer) and that PDF is what gets printed
// or saved. The older approach — handing an off-screen NSHostingView to NSPrintOperation —
// printed blank pages, because a hosting view that's never been in a window never draws.

private enum PrintStyle {
    static let accent = Color(red: 0.16, green: 0.40, blue: 0.52)
    static let text = Color.black
    static let secondary = Color(white: 0.30)
    static let tertiary = Color(white: 0.50)
    static let card = Color(white: 0.955)
}

/// One unbreakable piece of the printout. Pages only break between blocks, so a step or a
/// buffer card is never cut in half (unless it's taller than a whole page on its own).
struct ProtocolPrintBlock {
    let view: AnyView
    /// Headings stay on the same page as whatever follows them.
    var keepWithNext: Bool = false
}

enum ProtocolPrintLayout {
    static func blocks(for p: LabProtocol) -> [ProtocolPrintBlock] {
        var blocks: [ProtocolPrintBlock] = [ProtocolPrintBlock(view: AnyView(titleBlock(p)))]

        if !p.purpose.isEmpty {
            blocks.append(ProtocolPrintBlock(view: AnyView(
                Text(p.purpose)
                    .font(.system(size: 12))
                    .foregroundStyle(PrintStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            )))
        }

        if !p.buffers.isEmpty {
            blocks.append(heading("Buffers & Solutions", systemImage: "drop"))
            for buffer in p.buffers {
                blocks.append(ProtocolPrintBlock(view: AnyView(bufferCard(buffer))))
            }
        }

        if !p.reagents.isEmpty {
            blocks.append(heading("Materials & Reagents", systemImage: "cross.vial"))
            let groups: [(title: String?, reagents: [Reagent])] = p.reagents.isUncategorized
                ? [(nil, p.reagents)]
                : p.reagents.groupedByCategory.map { ($0.category.title, $0.reagents) }
            for group in groups {
                if let title = group.title {
                    blocks.append(ProtocolPrintBlock(view: AnyView(
                        Text(title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PrintStyle.tertiary)
                            .padding(.top, 2)
                    ), keepWithNext: true))
                }
                for reagent in group.reagents {
                    blocks.append(ProtocolPrintBlock(view: AnyView(reagentRow(reagent))))
                }
            }
        }

        if !p.steps.isEmpty {
            blocks.append(heading("Procedure", systemImage: "list.number"))
            let numbers = p.steps.stepNumbers
            for (index, step) in p.steps.enumerated() {
                // Blank placeholder steps (and an untitled section holding only blanks) are
                // left off paper; they're still in the protocol itself.
                if step.kind != .section && isBlank(step) { continue }
                if step.kind == .section && step.text.isEmpty && sectionIsBlank(p.steps, from: index) { continue }
                switch step.kind {
                case .section:
                    blocks.append(ProtocolPrintBlock(view: AnyView(sectionHeading(step)), keepWithNext: true))
                case .note, .warning, .pause:
                    blocks.append(ProtocolPrintBlock(view: AnyView(callout(step))))
                case .step:
                    blocks.append(ProtocolPrintBlock(view: AnyView(stepRow(step, number: numbers[index]))))
                }
            }
        }
        return blocks
    }

    private static func isBlank(_ step: ProtocolStep) -> Bool {
        step.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && step.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && step.table == nil
            && step.dilution == nil
    }

    private static func sectionIsBlank(_ steps: [ProtocolStep], from sectionIndex: Int) -> Bool {
        for step in steps[(sectionIndex + 1)...] {
            if step.kind == .section { break }
            if !isBlank(step) { return false }
        }
        return true
    }

    // MARK: - Pieces

    private static func titleBlock(_ p: LabProtocol) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(p.name.isEmpty ? "Untitled Protocol" : p.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PrintStyle.text)
                if p.currentVersionNumber > 0 {
                    Text("v\(p.currentVersionNumber)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PrintStyle.tertiary)
                }
            }
            HStack(spacing: 10) {
                Text("Printed \(Date().formatted(date: .abbreviated, time: .omitted))")
                if let total = p.effectiveTotalMinutes {
                    Text("·")
                    Text("Total time \(DurationText.format(total))")
                }
                if !p.tags.isEmpty {
                    Text("·")
                    Text(p.tags.joined(separator: ", "))
                }
            }
            .font(.system(size: 10))
            .foregroundStyle(PrintStyle.tertiary)
        }
    }

    private static func heading(_ title: String, systemImage: String) -> ProtocolPrintBlock {
        ProtocolPrintBlock(view: AnyView(
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PrintStyle.text)
                .padding(.top, 8)
        ), keepWithNext: true)
    }

    private static func tickCircle() -> some View {
        Circle()
            .stroke(PrintStyle.tertiary, lineWidth: 1)
            .frame(width: 11, height: 11)
            .padding(.top, 2)
    }

    private static func bufferCard(_ buffer: BufferRecipe) -> some View {
        HStack(alignment: .top, spacing: 10) {
            tickCircle()
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(buffer.name.isEmpty ? "Untitled buffer" : buffer.name)
                        .font(.system(size: 12, weight: .semibold))
                    if !buffer.finalVolume.isEmpty {
                        Text("makes \(buffer.finalVolume)")
                            .font(.system(size: 10))
                            .foregroundStyle(PrintStyle.tertiary)
                    }
                }
                if !buffer.components.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                        GridRow {
                            Color.clear.frame(width: 5, height: 1)
                            Text("Component")
                            Text("Stock")
                            Text("Final")
                            Text("Add")
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PrintStyle.tertiary)
                        ForEach(buffer.components) { component in
                            GridRow {
                                Text("•")
                                    .fontWeight(.bold)
                                    .foregroundStyle(PrintStyle.accent)
                                Text(component.name)
                                Text(component.stockConcentration)
                                Text(component.finalConcentration)
                                Text(buffer.displayAmount(for: component))
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 11))
                        }
                    }
                }
                if !buffer.finalVolume.isEmpty || !buffer.solvent.isEmpty {
                    Label(bringToVolumeLine(buffer), systemImage: "arrow.turn.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(PrintStyle.accent.opacity(0.12))
                        )
                }
                if !buffer.instructions.isEmpty {
                    Text(buffer.instructions)
                        .font(.system(size: 10))
                        .foregroundStyle(PrintStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(PrintStyle.text)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(PrintStyle.card))
    }

    private static func bringToVolumeLine(_ buffer: BufferRecipe) -> String {
        var line = "Then bring to \(buffer.finalVolume.isEmpty ? "volume" : buffer.finalVolume)"
        if !buffer.solvent.isEmpty { line += " with \(buffer.solvent)" }
        if let solventVolume = buffer.solventVolume { line += " (≈ \(solventVolume))" }
        return line + "."
    }

    private static func reagentRow(_ reagent: Reagent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            tickCircle()
            Text(reagent.name)
                .font(.system(size: 11, weight: .medium))
            let amount = [reagent.amount, reagent.unit].filter { !$0.isEmpty }.joined(separator: " ")
            if !amount.isEmpty {
                Text(amount)
                    .font(.system(size: 11))
            }
            if !reagent.notes.isEmpty {
                Text(reagent.notes)
                    .font(.system(size: 10))
                    .foregroundStyle(PrintStyle.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(PrintStyle.text)
    }

    private static func sectionHeading(_ step: ProtocolStep) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(step.text.isEmpty ? "Section" : step.text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PrintStyle.text)
            Rectangle()
                .fill(PrintStyle.accent.opacity(0.4))
                .frame(height: 1)
        }
        .padding(.top, 6)
    }

    private static func stepRow(_ step: ProtocolStep, number: Int) -> some View {
        let flagColor: Color? = switch step.importance {
        case .critical: .red
        case .important: .orange
        case .normal: nil
        }
        var details: [String] = []
        if let minutes = step.durationMinutes { details.append("⏱ \(DurationText.format(minutes))") }
        if let temperature = step.temperatureCelsius { details.append("🌡 \(String(format: "%g", temperature)) °C") }

        return HStack(alignment: .top, spacing: 10) {
            tickCircle()
            Text("\(number).")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PrintStyle.accent)
                .frame(minWidth: 18, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.text)
                    .font(.system(size: 12))
                    .foregroundStyle(PrintStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !details.isEmpty || flagColor != nil {
                    HStack(spacing: 10) {
                        ForEach(details, id: \.self) { Text($0) }
                        if let flagColor {
                            Label(step.importance == .critical ? "CRITICAL" : "IMPORTANT", systemImage: "flag.fill")
                                .foregroundStyle(flagColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(PrintStyle.secondary)
                }
                if !step.notes.isEmpty {
                    Text(step.notes)
                        .font(.system(size: 10))
                        .italic()
                        .foregroundStyle(PrintStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let table = step.table {
                    printTable(table)
                        .padding(.top, 2)
                }
                if let dilution = step.dilution {
                    Text(dilution.printedLine)
                        .font(.system(size: 10))
                        .foregroundStyle(PrintStyle.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(flagColor?.opacity(0.10) ?? PrintStyle.card)
        )
    }

    private static func printTable(_ table: StepTable) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !table.title.isEmpty {
                Text(table.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PrintStyle.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 3) {
                GridRow {
                    ForEach(table.columns.indices, id: \.self) { column in
                        Text(table.columns[column])
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                Divider()
                ForEach(table.rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(table.columns.indices, id: \.self) { column in
                            Text(table.rows[row].indices.contains(column) ? table.rows[row][column] : "")
                                .font(.system(size: 10))
                        }
                    }
                }
            }
            .foregroundStyle(PrintStyle.text)
            .padding(6)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.6), lineWidth: 0.5))
        }
    }

    private static func callout(_ step: ProtocolStep) -> some View {
        let color: Color = switch step.kind {
        case .warning: .orange
        case .pause: .teal
        default: .blue
        }
        let label = switch step.kind {
        case .warning: "WARNING"
        case .pause: "⏸ PAUSE POINT — safe to stop here"
        default: "NOTE"
        }
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PrintStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            Spacer(minLength: 0)
        }
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - PDF

@MainActor
enum ProtocolPDFRenderer {
    static let margin: CGFloat = 40
    private static let blockSpacing: CGFloat = 8
    private static let footerHeight: CGFloat = 16

    /// A multi-page PDF of the protocol at the given paper size (points).
    static func pdfData(for protocolItem: LabProtocol, paperSize: CGSize = NSPrintInfo.shared.paperSize) -> Data {
        let width = paperSize.width - 2 * margin
        let contentHeight = paperSize.height - 2 * margin - footerHeight

        let items: [(renderer: ImageRenderer<AnyView>, height: CGFloat, keepWithNext: Bool)] =
            ProtocolPrintLayout.blocks(for: protocolItem).map { block in
                let renderer = renderer(for: block.view, width: width)
                return (renderer, measuredHeight(renderer), block.keepWithNext)
            }

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: paperSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let title = protocolItem.name.isEmpty ? "Untitled Protocol" : protocolItem.name
        var pageNumber = 0
        var y: CGFloat = 0 // distance from the top of the current page's content area

        func startPage() {
            if pageNumber > 0 { context.endPDFPage() }
            context.beginPDFPage(nil)
            pageNumber += 1
            y = 0
            let footer = renderer(for: AnyView(
                HStack {
                    Text(title)
                    Spacer()
                    Text("Page \(pageNumber)")
                }
                .font(.system(size: 8))
                .foregroundStyle(PrintStyle.tertiary)
            ), width: width)
            draw(footer, in: context, x: margin, bottomY: margin - 4)
        }

        /// Draws a block whose top edge sits `top` points below the content area's top edge.
        func place(_ renderer: ImageRenderer<AnyView>, height: CGFloat, top: CGFloat) {
            draw(renderer, in: context, x: margin, bottomY: paperSize.height - margin - top - height)
        }

        startPage()
        for (index, item) in items.enumerated() {
            var needed = item.height
            if item.keepWithNext, index + 1 < items.count {
                needed += blockSpacing + min(items[index + 1].height, contentHeight / 3)
            }
            if y > 0 && y + needed > contentHeight {
                startPage()
            }

            if item.height <= contentHeight - y {
                place(item.renderer, height: item.height, top: y)
                y += item.height + blockSpacing
            } else {
                // Taller than a whole page on its own (e.g. a huge table): slice it across pages.
                var offset: CGFloat = 0
                while offset < item.height {
                    let slice = min(contentHeight - y, item.height - offset)
                    context.saveGState()
                    context.clip(to: CGRect(x: margin, y: paperSize.height - margin - y - slice, width: width, height: slice))
                    place(item.renderer, height: item.height, top: y - offset)
                    context.restoreGState()
                    offset += slice
                    y += slice
                    if offset < item.height { startPage() }
                }
                y += blockSpacing
            }
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private static func renderer(for view: AnyView, width: CGFloat) -> ImageRenderer<AnyView> {
        let content = AnyView(
            view
                .frame(width: width, alignment: .leading)
                .environment(\.colorScheme, .light)
        )
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer
    }

    private static func measuredHeight(_ renderer: ImageRenderer<AnyView>) -> CGFloat {
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        return ceil(height)
    }

    private static func draw(_ renderer: ImageRenderer<AnyView>, in context: CGContext, x: CGFloat, bottomY: CGFloat) {
        context.saveGState()
        context.translateBy(x: x, y: bottomY)
        renderer.render { _, drawContent in drawContent(context) }
        context.restoreGState()
    }
}

// MARK: - Printing

enum ProtocolPrinter {
    @MainActor
    static func print(_ protocolItem: LabProtocol) {
        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
        // The PDF already has its own margins drawn in.
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0

        let data = ProtocolPDFRenderer.pdfData(for: protocolItem, paperSize: printInfo.paperSize)
        guard let document = PDFDocument(data: data),
              let operation = document.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: false) else {
            return
        }
        operation.jobTitle = protocolItem.name.isEmpty ? "Untitled Protocol" : protocolItem.name
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}
