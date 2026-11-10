import AppKit
import ApplicationServices

/// Lists every Sound item MenuBarAgent hosts, with its frame.
func attr<T>(_ element: AXUIElement, _ name: String) -> T? {
    var value: CFTypeRef?; return AXUIElementCopyAttributeValue(
        element,
        name as CFString,
        &value
    ) == .success ? value as? T : nil
}

func walk(_ element: AXUIElement, _ depth: Int) {
    if (attr(element, kAXIdentifierAttribute) as String?) == "com.apple.menuextra.sound" {
        var position = CGPoint.zero; var size = CGSize.zero
        if let positionValue: AXValue = attr(element, kAXPositionAttribute) {
            AXValueGetValue(positionValue, .cgPoint, &position)
        }
        if let sizeValue: AXValue = attr(element, kAXSizeAttribute) {
            AXValueGetValue(sizeValue, .cgSize, &size)
        }
        print("sound item at", position, size)
    }
    guard depth < 12 else { return }
    for child in (attr(element, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
        walk(child, depth + 1)
    }
}

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else {
    fatalError("MenuBarAgent is not running")
}

walk(AXUIElementCreateApplication(app.processIdentifier), 0)
