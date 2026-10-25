import SwiftUI

struct UsagePopover: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Re-render every minute so countdowns tick between fetches.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 12) {
                    let blocked = store.blockedUntil > context.date
                    if store.limits.isEmpty && store.error == nil && !blocked {
                        Text("Loading…").foregroundStyle(.secondary)
                    }
                    ForEach(store.limits) { LimitRow(limit: $0, now: context.date) }
                    if blocked {
                        Text("Rate limited — retrying in \(countdown(to: store.blockedUntil, from: context.date))")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            }

            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if let lastUpdated = store.lastUpdated {
                (Text("Updated ") + Text(lastUpdated, style: .relative) + Text(" ago"))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Button("Refresh") { Task { await store.refresh() } }.disabled(store.isLoading)
                Button("Usage page") { NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 280)
    }
}

private struct LimitRow: View {
    let limit: Limit
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(limit.title).font(.callout.weight(.medium))
                Spacer()
                Text("\(limit.percent)%").font(.callout.monospacedDigit().weight(.semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule().fill(levelColor(limit.level))
                        .frame(width: geo.size.width * CGFloat(min(max(limit.percent, 0), 100)) / 100)
                }
            }
            .frame(height: 7)
            if let resetsAt = limit.resetsAt, resetsAt > now {
                Text("Resets in \(countdown(to: resetsAt, from: now))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

func levelColor(_ level: Int) -> Color {
    [Color.green, .orange, .red][min(max(level, 0), 2)]
}
