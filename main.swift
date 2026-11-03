import Cocoa
import ApplicationServices

// Catches the Play key. If Spotify is closed, opens Spotify with no window, starts playing, and stops
// Apple Music from seeing the key. If Spotify is open, lets the key through to Spotify.

let spotifyBundleID = "com.spotify.client"
let playKeyCode = 16  // NX_KEYTYPE_PLAY
let systemDefinedEvent: UInt32 = 14  // NX_SYSDEFINED
let mediaKeySubtype: Int16 = 8  // NX_SUBTYPE_AUX_CONTROL_BUTTONS

func spotifyIsRunning() -> Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: spotifyBundleID).isEmpty
}

func openSpotifyAndPlay() {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: spotifyBundleID) else { return }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.arguments = ["--minimized"]  // Spotify then opens with no window.
    configuration.activates = false  // Do not take focus.
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
        // Use a separate osascript process, off the main thread. In testing, NSAppleScript
        // on a background thread stopped the main thread's timers.
        DispatchQueue.global().async {
            let osascript = Process()
            osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            osascript.arguments = ["-e", "tell application \"Spotify\" to play"]
            do {
                try osascript.run()
                osascript.waitUntilExit()
                if osascript.terminationStatus != 0 { fputs("Spotify play command failed.\n", stderr) }
            } catch {
                fputs("Could not run osascript: \(error)\n", stderr)
            }
        }
    }
}

var tap: CFMachPort?

let callback: CGEventTapCallBack = { _, type, event, _ in
    let passThrough = Unmanaged.passUnretained(event)

    // macOS switches the tap off if it is slow. Switch it back on.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return passThrough
    }

    guard type.rawValue == systemDefinedEvent,
          let nsEvent = NSEvent(cgEvent: event),
          nsEvent.subtype.rawValue == mediaKeySubtype
    else { return passThrough }

    let keyCode = (nsEvent.data1 & 0xFFFF0000) >> 16
    let isKeyDown = ((nsEvent.data1 & 0xFF00) >> 8) == 0xA
    guard keyCode == playKeyCode, !spotifyIsRunning() else { return passThrough }

    if isKeyDown { openSpotifyAndPlay() }
    return nil  // Swallow both key down and key up.
}

let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(options) else {
    fputs("No Accessibility permission. Allow this program in System Settings > Privacy & Security > Accessibility, then run it again.\n", stderr)
    exit(1)
}

guard let createdTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << systemDefinedEvent),
    callback: callback,
    userInfo: nil
) else {
    fputs("Could not create the key tap.\n", stderr)
    exit(1)
}

tap = createdTap
let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
CGEvent.tapEnable(tap: createdTap, enable: true)
CFRunLoopRun()
