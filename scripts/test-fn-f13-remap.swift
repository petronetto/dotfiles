#!/usr/bin/env swift

// Manual, local debug script: verify that fn is currently emitting F13.
//
// `hidutil monitor` is unavailable on this macOS version. A terminal
// escape-sequence check is unreliable (depends on the terminal's own
// keybinding table), and IOHIDManager reads raw device reports *before*
// hidutil's UserKeyMapping remap is applied, so it never sees the
// remapped key either. This instead uses a CGEventTap, which reads events
// *after* the HID remap (the same layer apps like Terminal/Ghostty
// actually receive input through), and checks for macOS virtual keycode
// kVK_F13 (0x69).
//
// Usage: scripts/test-fn-f13-remap.swift
//   Run it, press the fn key once when prompted, read the pass/fail result.
// Requires the "Accessibility" and/or "Input Monitoring" privacy
// permission for the app running this script (Terminal.app, Ghostty,
// etc.) — grant both in System Settings > Privacy & Security if the event
// tap fails to create.
// Reverts nothing; read-only check.

import CoreGraphics
import Foundation

let kVK_F13: Int64 = 0x69

let callback: CGEventTapCallBack = { _, type, event, _ in
  guard type == .keyDown else {
    return Unmanaged.passRetained(event)
  }

  let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

  if keyCode == kVK_F13 {
    print("✅ fn is correctly mapped to F13 (keyCode 0x69 detected)")
    exit(0)
  }

  FileHandle.standardError.write(
    "Saw a different key: keyCode=0x\(String(keyCode, radix: 16))\n".data(using: .utf8)!)

  return Unmanaged.passRetained(event)
}

guard
  let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
    callback: callback,
    userInfo: nil)
else {
  print(
    "❌ Failed to create event tap. Check System Settings > Privacy & Security > "
      + "Accessibility and Input Monitoring for this terminal app.")
  exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

print("Press the fn key now (waiting up to 8 seconds)...")

DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
  print("❌ No key detected within the timeout. Try again and press fn only.")
  exit(1)
}

CFRunLoopRun()
