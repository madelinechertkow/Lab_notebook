import Foundation

extension LabProtocol {
    /// The protocol as a readable Markdown document — used for the Box backup, so a protocol
    /// can be opened and followed from Box (or any Markdown viewer) without Cazzy.
    /// Mirrors the printout's structure: buffers, materials, then the procedure.
    var markdownBody: String {
        var out = "# \(name.isEmpty ? "Untitled Protocol" : name)\n\n"
        if currentVersionNumber > 0 {
            out += "*Version \(currentVersionNumber)*\n\n"
        }
        if !purpose.isEmpty {
            out += "**Purpose:** \(purpose)\n\n"
        }

        if !buffers.isEmpty {
            out += "## Buffers & Solutions\n\n"
            for buffer in buffers {
                out += "### \(buffer.name.isEmpty ? "Untitled buffer" : buffer.name)"
                if !buffer.finalVolume.isEmpty { out += " — makes \(buffer.finalVolume)" }
                out += "\n\n"
                if !buffer.components.isEmpty {
                    out += "| Component | Stock | Final | Amount to add |\n|---|---|---|---|\n"
                    for component in buffer.components {
                        let cells = [component.name, component.stockConcentration, component.finalConcentration, buffer.displayAmount(for: component)]
                        out += "| " + cells.map(Self.tableCell).joined(separator: " | ") + " |\n"
                    }
                    out += "\n"
                }
                if !buffer.finalVolume.isEmpty || !buffer.solvent.isEmpty {
                    out += "Bring to \(buffer.finalVolume.isEmpty ? "volume" : buffer.finalVolume)"
                    if !buffer.solvent.isEmpty { out += " with \(buffer.solvent)" }
                    if let solventVolume = buffer.solventVolume { out += " (≈ \(solventVolume))" }
                    out += ".\n\n"
                }
                if !buffer.instructions.isEmpty {
                    out += "\(buffer.instructions)\n\n"
                }
            }
        }

        if !reagents.isEmpty {
            out += "## Materials & Reagents\n\n| Name | Amount | Notes |\n|---|---|---|\n"
            for reagent in reagents {
                let amount = [reagent.amount, reagent.unit].filter { !$0.isEmpty }.joined(separator: " ")
                out += "| " + [reagent.name, amount, reagent.notes].map(Self.tableCell).joined(separator: " | ") + " |\n"
            }
            out += "\n"
        }

        if !steps.isEmpty {
            out += "## Procedure\n\n"
            let numbers = steps.stepNumbers
            for (index, step) in steps.enumerated() {
                switch step.kind {
                case .section:
                    out += "\n### \(step.text.isEmpty ? "Section" : step.text)\n\n"
                case .note, .warning:
                    out += "> **\(step.kind == .warning ? "WARNING" : "NOTE"):** \(step.text)\n\n"
                case .step:
                    var details: [String] = []
                    if let minutes = step.durationMinutes { details.append(DurationText.format(minutes)) }
                    if let temperature = step.temperatureCelsius { details.append("\(String(format: "%g", temperature)) °C") }
                    switch step.importance {
                    case .normal: break
                    case .important: details.append("**IMPORTANT**")
                    case .critical: details.append("**CRITICAL**")
                    }
                    out += "\(numbers[index]). \(step.text)"
                    if !details.isEmpty { out += " — " + details.joined(separator: " · ") }
                    out += "\n"
                    if !step.notes.isEmpty { out += "   *\(step.notes)*\n" }
                }
            }
        }
        return out
    }

    /// Pipes and newlines would break a Markdown table row.
    private static func tableCell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }
}
