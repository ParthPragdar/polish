import CoreGraphics
import Foundation

/// Pure geometry in AppKit global points. Display origins may be negative or stacked.
public enum PopupPlacement {
    public static func appKitRect(fromAX rect: CGRect, primaryScreenTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenTop - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Prefer the caret, then the editable field, then its window. No pointer dependency.
    public static func anchor(caret: CGRect?, field: CGRect?, window: CGRect?, screens: [CGRect]) -> CGRect? {
        func visible(_ rect: CGRect?) -> CGRect? {
            guard var rect, rect.origin.x.isFinite, rect.origin.y.isFinite,
                  rect.width.isFinite, rect.height.isFinite, rect.width >= 0, rect.height > 0 else { return nil }
            rect.size.width = max(1, rect.width) // Insertion-point bounds may have zero width.
            guard screens.contains(where: { $0.intersects(rect) }) else { return nil }
            return rect
        }
        let window = visible(window)
        var field = visible(field)
        if let bounds = field, let window {
            field = visible(bounds.intersection(window))
        }
        if let caret = visible(caret) {
            // Ignore stale/bogus selection rectangles from web editors on another screen.
            if let owner = field ?? window {
                if owner.insetBy(dx: -4, dy: -4).intersects(caret) { return caret }
            } else { return caret }
        }
        return field ?? window
    }

    public static func screenIndex(for anchor: CGRect, screens: [CGRect]) -> Int? {
        guard !screens.isEmpty else { return nil }
        let areas = screens.map { screen -> CGFloat in
            let intersection = screen.intersection(anchor)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        if let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 { return best }
        // A display may have been disconnected while the request was running.
        return screens.indices.min { left, right in
            func distance(_ rect: CGRect) -> CGFloat {
                let dx = max(rect.minX - anchor.midX, 0, anchor.midX - rect.maxX)
                let dy = max(rect.minY - anchor.midY, 0, anchor.midY - rect.maxY)
                return dx * dx + dy * dy
            }
            return distance(screens[left]) < distance(screens[right])
        }
    }

    public static func origin(for size: CGSize, beside anchor: CGRect, visibleFrame: CGRect) -> CGPoint {
        let margin: CGFloat = 12
        let gap: CGFloat = 10
        let safe = visibleFrame.insetBy(dx: margin, dy: margin)
        let below = anchor.minY - gap - size.height
        let above = anchor.maxY + gap
        let y: CGFloat
        if below >= safe.minY { y = below }
        else if above + size.height <= safe.maxY { y = above }
        else { y = (anchor.minY - safe.minY > safe.maxY - anchor.maxY) ? below : above }
        return CGPoint(
            x: min(max(anchor.minX, safe.minX), max(safe.minX, safe.maxX - size.width)),
            y: min(max(y, safe.minY), max(safe.minY, safe.maxY - size.height))
        )
    }
}
