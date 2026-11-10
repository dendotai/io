import CoreGraphics
import Foundation

// pointer move X Y | click X Y | rightclick X Y | drag X Y1 Y2 | draghold X Y1 Y2 | pausedrag X Y1 Y2 | slowdrag X Y1 Y2 | fastdrag X Y1 Y2, in global points.
let args = CommandLine.arguments.dropFirst().map(\.self)
func number(_ index: Int) -> Double {
    guard index < args.count, let value = Double(args[index]) else {
        FileHandle.standardError.write(Data(
            "usage: pointer move X Y | click X Y | rightclick X Y | drag X Y1 Y2 | draghold X Y1 Y2 | pausedrag X Y1 Y2 | slowdrag X Y1 Y2 | fastdrag X Y1 Y2\n"
                .utf8
        ))
        exit(1)
    }
    return value
}

let x = number(1), y = number(2)

func post(_ type: CGEventType, _ pointX: Double, _ pointY: Double) {
    let event = CGEvent(
        mouseEventSource: nil,
        mouseType: type,
        mouseCursorPosition: CGPoint(x: pointX, y: pointY),
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
    let targetY = number(3)
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(150_000)
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (targetY - y) * Double(step) / 20)
        usleep(20000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, targetY)
case "rightclick":
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.rightMouseDown, x, y)
    usleep(150_000)
    post(.rightMouseUp, x, y)
case "draghold":
    let targetY = number(3)
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(150_000)
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (targetY - y) * Double(step) / 20)
        usleep(20000)
    }
    sleep(3)
    post(.leftMouseUp, x, targetY)
case "pausedrag":
    let targetY = number(3)
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(400_000)
    post(.leftMouseDragged, x, y + (targetY > y ? 1 : -1))
    usleep(300_000)
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (targetY - y) * Double(step) / 20)
        usleep(20000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, targetY)
case "slowdrag":
    let targetY = number(3)
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    for step in 1 ... 3 {
        usleep(80000)
        post(.leftMouseDragged, x, y + Double(step) * (targetY > y ? 1 : -1))
    }
    for step in 1 ... 20 {
        post(.leftMouseDragged, x, y + (targetY - y) * Double(step) / 20)
        usleep(20000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, targetY)
case "fastdrag":
    let targetY = number(3)
    post(.mouseMoved, x, y)
    usleep(100_000)
    post(.leftMouseDown, x, y)
    usleep(8000)
    let steps = Int(abs(targetY - y))
    for step in 1 ... steps {
        post(.leftMouseDragged, x, y + Double(step) * (targetY > y ? 1 : -1))
        usleep(8000)
    }
    usleep(150_000)
    post(.leftMouseUp, x, targetY)
default:
    break
}
