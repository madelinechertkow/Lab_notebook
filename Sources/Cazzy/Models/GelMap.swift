import Foundation
import AppKit

enum GelSizeUnit: String, Codable, CaseIterable, Identifiable {
    case bp, kb, kDa

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bp: return "bp"
        case .kb: return "kb"
        case .kDa: return "kDa"
        }
    }
}

/// One marker in a ladder's size list — no position; positions only exist once a ladder is
/// placed onto a specific photo (see `GelPositionedLadderBand`).
struct GelLadderBand: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var sizeValue: Double
    var unit: GelSizeUnit

    var sizeLabel: String {
        let isWhole = sizeValue.truncatingRemainder(dividingBy: 1) == 0
        let number = isWhole ? String(Int(sizeValue)) : String(sizeValue)
        return "\(number) \(unit.label)"
    }
}

/// A reusable ladder definition saved in the library — this is the part that's genuinely
/// reused run after run, unlike any specific gel photo.
struct GelLadderPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// Ordered largest → smallest, matching how a ladder reads top-to-bottom on a gel.
    var bands: [GelLadderBand] = []
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

/// A lane label placed on an imported gel photo — just an identity, not a measurement.
struct GelLaneLabel: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Fraction (0...1) across the image's width.
    var xPosition: Double = 0.5
    var text: String = ""
}

/// A ladder size label placed on an imported gel photo, dragged to roughly align with the
/// visible band. Purely a label for reading off the photo — no calibration math is derived
/// from this position.
struct GelPositionedLadderBand: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Fraction (0...1) down the image's height.
    var yPosition: Double
    var sizeLabel: String
}

/// A note-embedded gel map: an imported photo plus lane and ladder-size labels placed on it.
/// Identified by the fence's block id, not its own id.
struct GelMapInstance: Codable, Equatable {
    /// Filename only (see `GelImageStore`); the file lives in Application Support/Cazzy/GelImages.
    var imageFileName: String
    var laneLabels: [GelLaneLabel] = []
    var ladderBands: [GelPositionedLadderBand] = []
}

/// Copies imported gel photos into Application Support/Cazzy/GelImages, since (unlike
/// everything else Cazzy persists) these are binary files, not JSON. Note content only ever
/// stores the filename returned here, never a path, so the whole app support folder stays
/// portable together.
///
/// Known v1 limitation: deleting a gel map block from a note does not delete its image file.
/// Left as an accepted cost rather than risking an undo bringing back a reference to a file
/// that garbage collection already removed.
enum GelImageStore {
    private static var directory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Cazzy", isDirectory: true).appendingPathComponent("GelImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copies the file at `sourceURL` into the gel images folder under a fresh name, returning
    /// the filename to store on a `GelMapInstance`.
    static func importImage(from sourceURL: URL) throws -> String {
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = directory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return filename
    }

    static func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    static func loadImage(_ filename: String) -> NSImage? {
        NSImage(contentsOf: url(for: filename))
    }

    /// Saves an in-memory image (e.g. the output of `GelImageProcessor.straighten`/`crop`) as
    /// a new file, returning its filename. Always a new file, never overwriting the original,
    /// so a crop/rotate can be re-adjusted without compounding on already-processed pixels.
    static func saveProcessedImage(_ image: NSImage) throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let filename = "\(UUID().uuidString).png"
        try pngData.write(to: directory.appendingPathComponent(filename))
        return filename
    }
}
