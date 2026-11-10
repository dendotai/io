import ApplicationServices
import Foundation

// axpos <pid>: prints "x y w h" of the open panel's "Listening Mode" button, in global points (top-left origin), by Accessibility.
guard CommandLine.arguments.count > 1, let pid = pid_t(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: axpos <pid>\n".utf8))
    exit(1)
}

func attr<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?; AXUIElementCopyAttributeValue(
        element,
        attribute as CFString,
        &value
    ); return value as? T
}

func find(_ element: AXUIElement) -> AXUIElement? {
    if (attr(element, kAXRoleAttribute) as String?) == "AXButton",
       [kAXDescriptionAttribute, kAXTitleAttribute].contains(where: { (attr(
           element,
           $0
       ) as String?) == "Listening Mode" })
    {
        return element
    }
    for child in (attr(element, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
        if let found = find(child) {
            return found
        }
    }
    return nil
}

let app = AXUIElementCreateApplication(pid)
guard let bar: AXUIElement = attr(app, "AXExtrasMenuBar"),
      let button = find(bar) else { print("button not found"); exit(1) }
guard let positionValue: AXValue = attr(button, kAXPositionAttribute),
      let sizeValue: AXValue = attr(button, kAXSizeAttribute) else { print("button frame not readable"); exit(1) }
var position = CGPoint.zero, size = CGSize.zero
AXValueGetValue(positionValue, .cgPoint, &position)
AXValueGetValue(sizeValue, .cgSize, &size)
print("\(Int(position.x)) \(Int(position.y)) \(Int(size.width)) \(Int(size.height))")
