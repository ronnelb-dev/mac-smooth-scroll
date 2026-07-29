import Foundation

enum ScrollEventDisposition: Equatable {
    case passThrough
    case transform
}

struct ScrollEventFilter {
    static let syntheticMarker: Int64 = 0x4D_53_53_43_52_4F_4C_4C

    func disposition(
        sourceUserData: Int64,
        isContinuous: Bool
    ) -> ScrollEventDisposition {
        guard sourceUserData != Self.syntheticMarker,
              !isContinuous
        else {
            return .passThrough
        }

        return .transform
    }
}
