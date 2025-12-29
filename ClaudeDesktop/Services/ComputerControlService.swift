import Foundation
import AppKit
import CoreGraphics

class ComputerControlService {

    func execute(action: ComputerAction) async -> ToolResult {
        switch action.action {
        case .screenshot:
            return captureScreen()

        case .mouse_move:
            if let coord = action.coordinate, coord.count >= 2 {
                moveMouse(to: CGPoint(x: coord[0], y: coord[1]))
            }
            return captureScreen()

        case .left_click:
            if let coord = action.coordinate, coord.count >= 2 {
                click(at: CGPoint(x: coord[0], y: coord[1]), button: .left)
            }
            return captureScreen()

        case .right_click:
            if let coord = action.coordinate, coord.count >= 2 {
                click(at: CGPoint(x: coord[0], y: coord[1]), button: .right)
            }
            return captureScreen()

        case .double_click:
            if let coord = action.coordinate, coord.count >= 2 {
                doubleClick(at: CGPoint(x: coord[0], y: coord[1]))
            }
            return captureScreen()

        case .middle_click:
            if let coord = action.coordinate, coord.count >= 2 {
                click(at: CGPoint(x: coord[0], y: coord[1]), button: .center)
            }
            return captureScreen()

        case .left_click_drag:
            // For drag, coordinate should have 4 values: [startX, startY, endX, endY]
            if let coord = action.coordinate, coord.count >= 4 {
                drag(from: CGPoint(x: coord[0], y: coord[1]),
                     to: CGPoint(x: coord[2], y: coord[3]))
            }
            return captureScreen()

        case .type:
            if let text = action.text {
                typeText(text)
            }
            return captureScreen()

        case .key:
            if let key = action.text {
                pressKey(key)
            }
            return captureScreen()

        case .scroll:
            if let coord = action.coordinate, coord.count >= 2 {
                scroll(deltaX: coord[0], deltaY: coord[1])
            }
            return captureScreen()

        case .cursor_position:
            let pos = NSEvent.mouseLocation
            let screen = NSScreen.main ?? NSScreen.screens[0]
            let flippedY = screen.frame.height - pos.y
            return ToolResult(screenshotBase64: nil, text: "Cursor position: (\(Int(pos.x)), \(Int(flippedY)))")
        }
    }

    // MARK: - Screen Capture

    private func captureScreen() -> ToolResult {
        let displayID = CGMainDisplayID()

        guard let screenshot = CGDisplayCreateImage(displayID) else {
            return ToolResult(screenshotBase64: nil, text: "Failed to capture screen")
        }

        let bitmapRep = NSBitmapImageRep(cgImage: screenshot)

        // Scale down for API (max 1280px width to reduce token usage)
        let maxWidth: CGFloat = 1280
        let scale = min(1.0, maxWidth / CGFloat(screenshot.width))

        let scaledWidth = Int(CGFloat(screenshot.width) * scale)
        let scaledHeight = Int(CGFloat(screenshot.height) * scale)

        guard let scaledRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: scaledWidth,
            pixelsHigh: scaledHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return ToolResult(screenshotBase64: nil, text: "Failed to create scaled image")
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaledRep)
        NSGraphicsContext.current?.imageInterpolation = .high

        let sourceImage = NSImage(cgImage: screenshot, size: NSSize(width: screenshot.width, height: screenshot.height))
        sourceImage.draw(in: NSRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = scaledRep.representation(using: .png, properties: [:]) else {
            return ToolResult(screenshotBase64: nil, text: "Failed to encode image")
        }

        let base64 = pngData.base64EncodedString()
        return ToolResult(screenshotBase64: base64, text: nil)
    }

    // MARK: - Mouse Control

    private func moveMouse(to point: CGPoint) {
        let flippedPoint = flipY(point)
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedPoint, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }

    private func click(at point: CGPoint, button: CGMouseButton) {
        let flippedPoint = flipY(point)

        let downType: CGEventType
        let upType: CGEventType

        switch button {
        case .left:
            downType = .leftMouseDown
            upType = .leftMouseUp
        case .right:
            downType = .rightMouseDown
            upType = .rightMouseUp
        case .center:
            downType = .otherMouseDown
            upType = .otherMouseUp
        @unknown default:
            downType = .leftMouseDown
            upType = .leftMouseUp
        }

        // Move to position first
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedPoint, mouseButton: button)
        moveEvent?.post(tap: .cghidEventTap)

        // Small delay
        usleep(50000)

        // Click
        let downEvent = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: flippedPoint, mouseButton: button)
        downEvent?.post(tap: .cghidEventTap)

        usleep(50000)

        let upEvent = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: flippedPoint, mouseButton: button)
        upEvent?.post(tap: .cghidEventTap)
    }

    private func doubleClick(at point: CGPoint) {
        let flippedPoint = flipY(point)

        // Move to position
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedPoint, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)

        usleep(50000)

        // First click
        let down1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: flippedPoint, mouseButton: .left)
        down1?.setIntegerValueField(.mouseEventClickState, value: 1)
        down1?.post(tap: .cghidEventTap)

        let up1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: flippedPoint, mouseButton: .left)
        up1?.setIntegerValueField(.mouseEventClickState, value: 1)
        up1?.post(tap: .cghidEventTap)

        usleep(50000)

        // Second click
        let down2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: flippedPoint, mouseButton: .left)
        down2?.setIntegerValueField(.mouseEventClickState, value: 2)
        down2?.post(tap: .cghidEventTap)

        let up2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: flippedPoint, mouseButton: .left)
        up2?.setIntegerValueField(.mouseEventClickState, value: 2)
        up2?.post(tap: .cghidEventTap)
    }

    private func drag(from start: CGPoint, to end: CGPoint) {
        let flippedStart = flipY(start)
        let flippedEnd = flipY(end)

        // Move to start
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedStart, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)

        usleep(100000)

        // Mouse down
        let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: flippedStart, mouseButton: .left)
        downEvent?.post(tap: .cghidEventTap)

        usleep(100000)

        // Drag to end
        let dragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: flippedEnd, mouseButton: .left)
        dragEvent?.post(tap: .cghidEventTap)

        usleep(100000)

        // Mouse up
        let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: flippedEnd, mouseButton: .left)
        upEvent?.post(tap: .cghidEventTap)
    }

    private func scroll(deltaX: Int, deltaY: Int) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }

    // MARK: - Keyboard Control

    private func typeText(_ text: String) {
        for char in text {
            let source = CGEventSource(stateID: .hidSystemState)

            // Use CGEvent to type each character
            if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                var unicodeChar = Array(String(char).utf16)
                keyDownEvent.keyboardSetUnicodeString(stringLength: unicodeChar.count, unicodeString: &unicodeChar)
                keyDownEvent.post(tap: .cghidEventTap)
            }

            if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyUpEvent.post(tap: .cghidEventTap)
            }

            usleep(20000) // 20ms between keystrokes
        }
    }

    private func pressKey(_ keyString: String) {
        // Parse key combinations like "Return", "cmd+c", "ctrl+shift+a"
        let parts = keyString.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }

        var flags: CGEventFlags = []
        var keyCode: CGKeyCode = 0

        for part in parts {
            switch part {
            case "cmd", "command", "super":
                flags.insert(.maskCommand)
            case "ctrl", "control":
                flags.insert(.maskControl)
            case "alt", "option":
                flags.insert(.maskAlternate)
            case "shift":
                flags.insert(.maskShift)
            case "return", "enter":
                keyCode = 36
            case "escape", "esc":
                keyCode = 53
            case "tab":
                keyCode = 48
            case "space":
                keyCode = 49
            case "backspace", "delete":
                keyCode = 51
            case "up":
                keyCode = 126
            case "down":
                keyCode = 125
            case "left":
                keyCode = 123
            case "right":
                keyCode = 124
            case "home":
                keyCode = 115
            case "end":
                keyCode = 119
            case "pageup", "page_up":
                keyCode = 116
            case "pagedown", "page_down":
                keyCode = 121
            default:
                // Try single character
                if let char = part.first, part.count == 1 {
                    keyCode = keyCodeForCharacter(char)
                }
            }
        }

        let source = CGEventSource(stateID: .hidSystemState)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = flags
            keyDown.post(tap: .cghidEventTap)
        }

        usleep(50000)

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = flags
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Helpers

    private func flipY(_ point: CGPoint) -> CGPoint {
        // Convert from top-left origin (API) to bottom-left origin (macOS screen coordinates)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        return CGPoint(x: point.x, y: screen.frame.height - point.y)
    }

    private func keyCodeForCharacter(_ char: Character) -> CGKeyCode {
        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
            "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
            "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
            "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
            "`": 50
        ]

        return keyMap[Character(char.lowercased())] ?? 0
    }
}
