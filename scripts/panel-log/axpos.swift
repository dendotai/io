import ApplicationServices
import Foundation
// axpos <pid>: prints "x y w h" of the open panel's "Listening Mode" button, in global points (top-left origin), by Accessibility.
let pid = pid_t(CommandLine.arguments[1])!
func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var v: CFTypeRef?; AXUIElementCopyAttributeValue(e, a as CFString, &v); return v }
func find(_ e: AXUIElement) -> AXUIElement? {
    if (attr(e, kAXRoleAttribute) as? String) == "AXButton", [kAXDescriptionAttribute, kAXTitleAttribute].contains(where: { (attr(e, $0) as? String) == "Listening Mode" }) { return e }
    for c in attr(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] { if let f = find(c) { return f } }
    return nil
}
let app = AXUIElementCreateApplication(pid)
guard let bar = attr(app, "AXExtrasMenuBar"), let button = find(bar as! AXUIElement) else { print("button not found"); exit(1) }
var p = CGPoint.zero, s = CGSize.zero
AXValueGetValue(attr(button, kAXPositionAttribute) as! AXValue, .cgPoint, &p)
AXValueGetValue(attr(button, kAXSizeAttribute) as! AXValue, .cgSize, &s)
print("\(Int(p.x)) \(Int(p.y)) \(Int(s.width)) \(Int(s.height))")
