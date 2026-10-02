import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class TrayController {
    private let store = UsageStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var lastLevel: [String: Int] = [:]
    private var subscription: AnyCancellable?

    // UNUserNotificationCenter crashes outside an .app bundle (e.g. `swift run`).
    private let canNotify = Bundle.main.bundleIdentifier != nil

    init() {
        let hosting = NSHostingController(rootView: UsagePopover(store: store))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        statusItem.button?.title = "—"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        if canNotify {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        subscription = store.$limits.sink { [weak self] limits in
            self?.render(limits)
            self?.notifyIfEscalated(limits)
        }
        store.start()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Menu bar shows the first two limits (session · weekly), colored by level.
    private func render(_ limits: [Limit]) {
        guard !limits.isEmpty else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let title = NSMutableAttributedString()
        for (index, limit) in limits.prefix(2).enumerated() {
            if index > 0 {
                title.append(NSAttributedString(string: " · ", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
            }
            let color: NSColor = [.labelColor, .systemOrange, .systemRed][min(max(limit.level, 0), 2)]
            title.append(NSAttributedString(string: "\(limit.percent)%", attributes: [.font: font, .foregroundColor: color]))
        }
        statusItem.button?.attributedTitle = title
    }

    /// Notifies once per step up (ok → warning → critical). Usage only drops when a window
    /// resets, which lowers the stored level and re-arms the alert.
    private func notifyIfEscalated(_ limits: [Limit]) {
        for limit in limits {
            let previous = lastLevel[limit.id] ?? 0
            lastLevel[limit.id] = limit.level
            guard canNotify, limit.level > previous else { continue }

            let content = UNMutableNotificationContent()
            content.title = limit.level == 2 ? "Claude limit almost reached" : "Claude usage is getting high"
            content.body = "\(limit.title): \(limit.percent)% used"
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: limit.id, content: content, trigger: nil))
        }
    }
}
