import CoreGraphics

enum ScrollSpeedModifierAction: Equatable {
    case standard
    case faster
    case precise

    var multiplier: Double {
        switch self {
        case .standard: 1
        case .faster: 2.4
        case .precise: 0.28
        }
    }

    var allowsAdaptivePrecision: Bool {
        self == .standard
    }

    var allowsRapidInputAcceleration: Bool {
        self != .precise
    }
}

struct ScrollModifierResolution: Equatable {
    let convertsToHorizontal: Bool
    let speedAction: ScrollSpeedModifierAction
    let forwardedFlags: CGEventFlags
}

struct ScrollModifierResolver {
    func resolve(
        x: Double,
        y: Double,
        flags: CGEventFlags,
        configuration: ScrollTransformConfiguration
    ) -> ScrollModifierResolution {
        let convertsToHorizontal =
            configuration.horizontalModifier.isActive(in: flags) &&
            abs(y) >= abs(x)

        let speedAction: ScrollSpeedModifierAction
        if configuration.preciseModifier.isActive(in: flags) {
            speedAction = .precise
        } else if configuration.swiftModifier.isActive(in: flags) {
            speedAction = .faster
        } else {
            speedAction = .standard
        }

        let transformActionIsActive =
            convertsToHorizontal || speedAction != .standard
        let forwardsZoom =
            !transformActionIsActive &&
            configuration.zoomModifier.isActive(in: flags)

        return ScrollModifierResolution(
            convertsToHorizontal: convertsToHorizontal,
            speedAction: speedAction,
            forwardedFlags: forwardsZoom ? configuration.zoomModifier.flag : []
        )
    }
}
