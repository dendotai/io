import CoreGraphics
import Foundation

// pointer move X Y | click X Y | rightclick X Y | drag X Y1 Y2 | draghold X Y1 Y2 | pausedrag X Y1 Y2 | slowdrag X Y1 Y2 | fastdrag X Y1 Y2, in global points.
let args = CommandLine.arguments.dropFirst().map(\.self)
let x = Double(args[1])!, y = Double(args[2])!

func post(_ type: CGEventType, _ px: Double, _ py: Double) {
    let event = CGEvent(
        mouseEventSource: nil,
        mouseType: type,
        mouseCursorPosition: CGPoint(x: px, y: py),
        mouseButton: type == .rightMouseDown || type == .rightMouseUp ? .right : .left
    )
    event?.setIntegerValueField(.mouseEventClickState, value: 1)
    event?.post(tap: .cghidEventTap)
}

switch args[0] {
case "move":
    post(.mouseMoved, x, y)
case "click":
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(150_000)
    post(.leftMouseUp, x, y)
case "drag":
    let to = Double(args[3])!
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(150_000)
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (to - y) * Double(step) / 20)
        usleep(20000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, to)
case "rightclick":
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.rightMouseDown, x, y)
    usleep(150_000)
    post(.rightMouseUp, x, y)
case "draghold":
    let to = Double(args[3])!
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(150_000)
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (to - y) * Double(step) / 20)
        usleep(20000)
    }
    sleep(3)
    post(.leftMouseUp, x, to)
case "pausedrag":
    let to = Double(args[3])!
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(400_000)
    post(.leftMouseDragged, x, y + (to > y ? 1 : -1))
    usleep(300_000)
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (to - y) * Double(step) / 20)
        usleep(20000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, to)
case "slowdrag":
    let to = Double(args[3])!
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    for step in 1 ... 3 {
        usleep(80000)
        post(.leftMouseDragged, x, y + Double(step) * (to > y ? 1 : -1))
    }
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (to - y) * Double(step) / 20)
        usleep(20000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, to)
case "fastdrag":
    let to = Double(args[3])!
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(8000)
    let steps = Int(abs(to - y))
    for step in 1 ... steps {
        post(.leftMouseDragged, x, y + Double(step) * (to > y ? 1 : -1))
        usleep(8000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, to)
default:
    break
}
