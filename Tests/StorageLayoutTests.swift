import AppKit
import Foundation

@main
struct StorageLayoutTests {
    static func main() {
        testCapacityBreakdownLegendDoesNotClipAtDashboardWidth()
        print("Storage layout tests passed.")
    }

    private static func testCapacityBreakdownLegendDoesNotClipAtDashboardWidth() {
        let view = StorageBreakdownView()
        view.frame = NSRect(x: 0, y: 0, width: 640, height: StorageBreakdownView.minimumHeight)
        view.setBreakdown(
            [
                StorageCategorySummary(category: .system, sizeBytes: 507_710_000_000),
                StorageCategorySummary(category: .users, sizeBytes: 175_170_000_000),
                StorageCategorySummary(category: .applications, sizeBytes: 88_840_000_000),
                StorageCategorySummary(category: .caches, sizeBytes: 27_760_000_000),
                StorageCategorySummary(category: .downloads, sizeBytes: 69_300_000),
                StorageCategorySummary(category: .developer, sizeBytes: 20_000_000)
            ],
            totalBytes: 994_630_000_000
        )

        view.layoutSubtreeIfNeeded()
        view.frame.size.height = ceil(view.fittingSize.height)
        view.layoutSubtreeIfNeeded()

        let textFields = view.descendants(ofType: NSTextField.self).filter { !$0.stringValue.isEmpty }
        expect(textFields.count >= 7, "Expected all breakdown legend labels to be present.")

        for textField in textFields {
            let requiredWidth = textField.intrinsicContentSize.width
            expect(
                textField.bounds.width + 0.5 >= requiredWidth,
                "Expected legend label '\(textField.stringValue)' to have enough width; got \(textField.bounds.width), needs \(requiredWidth)."
            )

            let labelFrame = textField.convert(textField.bounds, to: view)
            expect(
                view.bounds.insetBy(dx: -0.5, dy: -0.5).contains(labelFrame),
                "Expected legend label '\(textField.stringValue)' to stay inside the breakdown view; label frame \(labelFrame), view bounds \(view.bounds), ancestors \(textField.debugAncestorFrames(upTo: view))."
            )
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}

private extension NSView {
    func descendants<T: NSView>(ofType type: T.Type) -> [T] {
        subviews.flatMap { child -> [T] in
            var matches = child.descendants(ofType: type)
            if let typed = child as? T {
                matches.insert(typed, at: 0)
            }
            return matches
        }
    }

    func debugAncestorFrames(upTo root: NSView) -> String {
        var parts: [String] = []
        var current: NSView? = self
        while let view = current {
            parts.append("\(type(of: view)):\(view.frame)")
            if view === root { break }
            current = view.superview
        }
        return parts.joined(separator: " -> ")
    }
}
