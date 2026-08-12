import Foundation

enum ModifierAssignment: CaseIterable, Equatable {
    case horizontal
    case zoom
    case faster
    case precision
    case bypass

    var title: String {
        switch self {
        case .horizontal: "Horizontal"
        case .zoom: "Zoom"
        case .faster: "Faster"
        case .precision: "Precision"
        case .bypass: "Bypass"
        }
    }
}

enum ModifierConflictTone: Equatable {
    case compatible
    case priority
}

struct ModifierConflictGuidance: Equatable, Identifiable {
    let key: ModifierKey
    let assignments: [ModifierAssignment]
    let tone: ModifierConflictTone
    let outcome: String

    var id: String { key.rawValue }

    var title: String {
        "\(key.symbol) \(key.title): \(assignments.map(\.title).joined(separator: " + "))"
    }
}

struct ModifierConflictAdvisor {
    func guidance(
        horizontal: ModifierKey,
        zoom: ModifierKey,
        faster: ModifierKey,
        precision: ModifierKey,
        bypass: ModifierKey
    ) -> [ModifierConflictGuidance] {
        let assignments: [(ModifierAssignment, ModifierKey)] = [
            (.horizontal, horizontal),
            (.zoom, zoom),
            (.faster, faster),
            (.precision, precision),
            (.bypass, bypass)
        ]

        return ModifierKey.allCases.compactMap { key in
            guard key != .none else { return nil }
            let shared = assignments.compactMap { assignment, assignedKey in
                assignedKey == key ? assignment : nil
            }
            guard shared.count > 1 else { return nil }
            return makeGuidance(key: key, assignments: shared)
        }
    }

    private func makeGuidance(
        key: ModifierKey,
        assignments: [ModifierAssignment]
    ) -> ModifierConflictGuidance {
        let assigned = Set(assignments)
        var tone: ModifierConflictTone
        let outcome: String

        if assigned.contains(.bypass) {
            tone = .priority
            outcome = "Bypass wins and sends the wheel event natively."
        } else if assigned.contains(.precision) {
            if assigned == [.horizontal, .precision] {
                tone = .compatible
                outcome = "These actions combine when the key is held."
                return ModifierConflictGuidance(
                    key: key,
                    assignments: assignments,
                    tone: tone,
                    outcome: outcome
                )
            }
            tone = .priority
            var effects: [String] = []
            if assigned.contains(.horizontal) {
                effects.append("Horizontal conversion combines with Precision")
            }
            if assigned.contains(.faster) {
                effects.append("Precision overrides Faster")
            }
            if assigned.contains(.zoom) {
                effects.append("Precision suppresses Zoom")
            }
            outcome = effects.joined(separator: "; ") + "."
        } else if assigned.contains(.faster) {
            tone = .priority
            var effects: [String] = []
            if assigned.contains(.horizontal) {
                effects.append("Horizontal conversion combines with Faster")
            }
            if assigned.contains(.zoom) {
                effects.append("Faster suppresses Zoom")
            }
            if effects.count == 1, assigned == [.horizontal, .faster] {
                tone = .compatible
                outcome = "These actions combine when the key is held."
            } else {
                outcome = effects.joined(separator: "; ") + "."
            }
        } else if assigned.contains(.zoom) && assigned.contains(.horizontal) {
            tone = .priority
            outcome = "Horizontal wins for vertical-dominant input; otherwise Zoom can run."
        } else {
            tone = .compatible
            outcome = "These actions combine when the key is held."
        }

        return ModifierConflictGuidance(
            key: key,
            assignments: assignments,
            tone: tone,
            outcome: outcome
        )
    }
}
