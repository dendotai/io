import AppKit
import ApplicationServices
// Lists every Sound item MenuBarAgent hosts, with its frame.
func attr<T>(_ e: AXUIElement, _ n: String) -> T? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v as? T : nil }
func walk(_ e: AXUIElement, _ d: Int = 0) {
    if (attr(e, kAXIdentifierAttribute) as String?) == "com.apple.menuextra.sound" {
        var p = CGPoint.zero; var s = CGSize.zero
        if let pv: AXValue = attr(e, kAXPositionAttribute) { AXValueGetValue(pv, .cgPoint, &p) }
        if let sv: AXValue = attr(e, kAXSizeAttribute) { AXValueGetValue(sv, .cgSize, &s) }
        print("sound item at", p, s)
    }
    guard d < 12 else { return }
    for c in (attr(e, kAXChildrenAttribute) as [AXUIElement]?) ?? [] { walk(c, d + 1) }
}
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first!
walk(AXUIElementCreateApplication(app.processIdentifier))
