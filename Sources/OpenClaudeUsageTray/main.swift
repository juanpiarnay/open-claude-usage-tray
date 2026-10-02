import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
let tray = MainActor.assumeIsolated { TrayController() }
app.run()
