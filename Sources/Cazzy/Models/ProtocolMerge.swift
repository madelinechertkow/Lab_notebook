import Foundation

/// Reconciles two diverged snapshots of the *same* protocol (matched by the parent
/// `LabProtocol.id`). This is a two-way diff keyed by each item's stable `id` — there's no
/// common-ancestor tracking, so a same-id-different-content pair is always surfaced as a
/// conflict rather than auto-resolved.
enum MergeChoice {
    case local
    case imported
}

enum ProtocolMerge {
    enum ItemDiff<T: Identifiable & Equatable> {
        case unchanged(T)
        case localOnly(T)
        case importedOnly(T)
        case conflict(local: T, imported: T)

        var id: T.ID {
            switch self {
            case .unchanged(let item), .localOnly(let item), .importedOnly(let item):
                return item.id
            case .conflict(let local, _):
                return local.id
            }
        }

        var isConflict: Bool {
            if case .conflict = self { return true }
            return false
        }
    }

    struct Result {
        var local: ProtocolVersionSnapshot
        var imported: ProtocolVersionSnapshot
        var nameConflict: (local: String, imported: String)?
        var purposeConflict: (local: String, imported: String)?
        var tags: [String]
        var reagentDiffs: [ItemDiff<Reagent>]
        var stepDiffs: [ItemDiff<ProtocolStep>]

        var hasConflicts: Bool {
            nameConflict != nil
                || purposeConflict != nil
                || reagentDiffs.contains { $0.isConflict }
                || stepDiffs.contains { $0.isConflict }
        }

        /// Ids of additions (present on only one side), included by default in the merge.
        var defaultIncludedReagentIDs: Set<UUID> {
            Set(reagentDiffs.compactMap { diff -> UUID? in
                switch diff {
                case .localOnly(let item), .importedOnly(let item): return item.id
                default: return nil
                }
            })
        }

        var defaultIncludedStepIDs: Set<UUID> {
            Set(stepDiffs.compactMap { diff -> UUID? in
                switch diff {
                case .localOnly(let item), .importedOnly(let item): return item.id
                default: return nil
                }
            })
        }
    }

    static func diff(local: ProtocolVersionSnapshot, imported: ProtocolVersionSnapshot) -> Result {
        let sortedTags = Array(Set(local.tags).union(imported.tags)).sorted()
        return Result(
            local: local,
            imported: imported,
            nameConflict: local.name == imported.name ? nil : (local.name, imported.name),
            purposeConflict: local.purpose == imported.purpose ? nil : (local.purpose, imported.purpose),
            tags: sortedTags,
            reagentDiffs: diffItems(local: local.reagents, imported: imported.reagents),
            stepDiffs: diffItems(local: local.steps, imported: imported.steps)
        )
    }

    private static func diffItems<T: Identifiable & Equatable>(local: [T], imported: [T]) -> [ItemDiff<T>] {
        let importedByID = Dictionary(uniqueKeysWithValues: imported.map { ($0.id, $0) })
        var handledImportedIDs = Set<T.ID>()
        var result: [ItemDiff<T>] = []

        for item in local {
            if let match = importedByID[item.id] {
                handledImportedIDs.insert(item.id)
                result.append(item == match ? .unchanged(item) : .conflict(local: item, imported: match))
            } else {
                result.append(.localOnly(item))
            }
        }
        for item in imported where !handledImportedIDs.contains(item.id) {
            result.append(.importedOnly(item))
        }
        return result
    }

    /// Produces a merged snapshot from the user's per-conflict choices and per-addition
    /// include/exclude decisions. The result becomes an unsaved draft in the editor — it is
    /// not itself saved as a new version until the user explicitly does so.
    static func resolve(
        _ result: Result,
        nameChoice: MergeChoice?,
        purposeChoice: MergeChoice?,
        reagentChoices: [UUID: MergeChoice],
        includedReagentIDs: Set<UUID>,
        stepChoices: [UUID: MergeChoice],
        includedStepIDs: Set<UUID>
    ) -> ProtocolVersionSnapshot {
        let name = result.nameConflict == nil
            ? result.local.name
            : (nameChoice == .imported ? result.imported.name : result.local.name)
        let purpose = result.purposeConflict == nil
            ? result.local.purpose
            : (purposeChoice == .imported ? result.imported.purpose : result.local.purpose)

        let reagents = resolveItems(result.reagentDiffs, choices: reagentChoices, includedIDs: includedReagentIDs)
        let steps = resolveItems(result.stepDiffs, choices: stepChoices, includedIDs: includedStepIDs)

        // Total-time override isn't worth its own conflict UI: keep local's, fall back to imported's.
        let manualTotalMinutes = result.local.manualTotalMinutes ?? result.imported.manualTotalMinutes

        return ProtocolVersionSnapshot(name: name, purpose: purpose, reagents: reagents, steps: steps, tags: result.tags, manualTotalMinutes: manualTotalMinutes)
    }

    private static func resolveItems<T: Identifiable & Equatable>(
        _ diffs: [ItemDiff<T>],
        choices: [UUID: MergeChoice],
        includedIDs: Set<UUID>
    ) -> [T] where T.ID == UUID {
        var merged: [T] = []

        // Unchanged + local-only items keep local order; conflicts resolve in place.
        for diff in diffs {
            switch diff {
            case .unchanged(let item):
                merged.append(item)
            case .localOnly(let item):
                if includedIDs.contains(item.id) { merged.append(item) }
            case .conflict(let local, let imported):
                let choice = choices[local.id] ?? .local
                merged.append(choice == .imported ? imported : local)
            case .importedOnly:
                continue
            }
        }

        // Imported-only additions append at the end; user reorders manually afterward.
        for diff in diffs {
            if case .importedOnly(let item) = diff, includedIDs.contains(item.id) {
                merged.append(item)
            }
        }

        return merged
    }
}
