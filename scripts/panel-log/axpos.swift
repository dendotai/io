import ApplicationServices
import Foundation

// axpos <pid>: prints "x y w h" of the open panel's "Listening Mode" button, in global points (top-left origin), by Accessibility.
let pid = pid_t(CommandLine.arguments[1])!
func attr(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?; AXUIElementCopyAttributeValue(
        element,
        attribute as CFString,
        &value
    ); return value
}

func find(_ element: AXUIElement) -> AXUIElement? {
    if (attr(element, kAXRoleAttribute) as? String) == "AXButton",
       [kAXDescriptionAttribute, kAXTitleAttribute].contains(where: { (attr(
           element,
           $0
       ) as? String) == "Listening Mode" })
    {
        return element
    }
    for child in attr(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        if let found = find(child) {
            return found
        }
    }
    return nil
}

let app = AXUIElementCreateApplication(pid)
guard let bar = attr(app, "AXExtrasMenuBar"),
      let button = find(bar as! AXUIElement) else { print("button not found"); exit(1) }
var position = CGPoint.zero, size = CGSize.zero
AXValueGetValue(attr(button, kAXPositionAttribute) as! AXValue, .cgPoint, &position)
AXValueGetValue(attr(button, kAXSizeAttribute) as! AXValue, .cgSize, &size)
print("\(Int(position.x)) \(Int(position.y)) \(Int(size.width)) \(Int(size.height))")
