import Foundation

/// A reusable shell activation snippet (e.g. `conda activate ds`, `source ~/venvs/x/bin/activate`)
/// run before a code block's interpreter, so a note's scripts execute inside a specific
/// environment instead of whatever happens to be active in the user's default login shell.
/// Notes reference one of these by id (not a copy) — renaming/fixing an environment here
/// should update every note that uses it.
struct CodeEnvironment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var activationCommand: String = ""
}
