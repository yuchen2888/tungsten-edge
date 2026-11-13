import CoreGraphics
import Foundation

struct WindowFrameMatchPolicy {
    static let tolerance: CGFloat = 24

    static func areClose(
        _ lhs: CGRect,
        _ rhs: CGRect,
        tolerance: CGFloat = Self.tolerance
    ) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    static func score(_ lhs: CGRect, _ rhs: CGRect) -> Int {
        // 自用改版：拆成显式 CGFloat 中间量。四项连加在较慢的 Intel 构建机上会触发
        // 「unable to type-check this expression in reasonable time」，语义不变。
        let dx: CGFloat = abs(lhs.origin.x - rhs.origin.x)
        let dy: CGFloat = abs(lhs.origin.y - rhs.origin.y)
        let dw: CGFloat = abs(lhs.width - rhs.width)
        let dh: CGFloat = abs(lhs.height - rhs.height)
        let total: CGFloat = dx + dy + dw + dh
        return Int(total)
    }

    static func signature(for bounds: CGRect?) -> String {
        guard let bounds else { return "no-frame" }
        return "\(Int(bounds.origin.x.rounded())):\(Int(bounds.origin.y.rounded())):\(Int(bounds.width.rounded())):\(Int(bounds.height.rounded()))"
    }
}
