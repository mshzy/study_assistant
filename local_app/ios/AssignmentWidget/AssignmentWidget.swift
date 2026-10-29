import SwiftUI
import WidgetKit
import Foundation

private let appGroupId = "group.com.example.studyassistant"
private let snapshotKey = "assignment_snapshot"

struct AssignmentEntry: TimelineEntry {
    let date: Date
    let items: [AssignmentSnapshotItem]
}

struct AssignmentSnapshotItem: Codable, Identifiable {
    let assignmentId: String
    let title: String
    let courseName: String
    let deadlineAt: String
    let remainingText: String
    let urgencyLevel: String
    let deepLinkUrl: String

    var id: String { assignmentId }

    var deadlineDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: deadlineAt) ?? ISO8601DateFormatter().date(from: deadlineAt)
    }

    var remainingTextNow: String {
        guard let deadlineDate else { return remainingText }
        let minutes = Int(deadlineDate.timeIntervalSinceNow / 60)
        if minutes <= 0 { return "已截止" }
        if minutes < 60 { return "\(minutes)分钟" }
        let hours = Int(ceil(Double(minutes) / 60))
        if hours < 24 { return "\(hours)小时" }
        return "\(Int(ceil(Double(hours) / 24)))天"
    }

    var urgencyLevelNow: String {
        guard let deadlineDate else { return urgencyLevel }
        let hours = Int(deadlineDate.timeIntervalSinceNow / 3600)
        if hours <= 3 { return "critical" }
        if hours <= 24 { return "soon" }
        return "normal"
    }
}

struct AssignmentProvider: TimelineProvider {
    func placeholder(in context: Context) -> AssignmentEntry {
        AssignmentEntry(date: Date(), items: [
            AssignmentSnapshotItem(
                assignmentId: "placeholder",
                title: "需求分析报告",
                courseName: "软件工程",
                deadlineAt: ISO8601DateFormatter().string(from: Date()),
                remainingText: "3小时",
                urgencyLevel: "soon",
                deepLinkUrl: "studyassistant://assignments/placeholder"
            )
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (AssignmentEntry) -> Void) {
        completion(AssignmentEntry(date: Date(), items: loadItems()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AssignmentEntry>) -> Void) {
        let entry = AssignmentEntry(date: Date(), items: loadItems())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadItems() -> [AssignmentSnapshotItem] {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: snapshotKey),
            let data = raw.data(using: .utf8),
            let items = try? JSONDecoder().decode([AssignmentSnapshotItem].self, from: data)
        else {
            return []
        }
        return items
    }
}

struct AssignmentWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AssignmentEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("待完成")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.items.count)")
                    .font(.caption.monospacedDigit().weight(.bold))
            }

            if entry.items.isEmpty {
                Spacer()
                Text("暂无作业")
                    .font(.headline)
                Text("打开 App 同步学习通")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.items.prefix(limitForFamily), id: \.assignmentId) { item in
                    Link(destination: URL(string: item.deepLinkUrl)!) {
                        HStack(alignment: .top, spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: item.urgencyLevelNow))
                                .frame(width: 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                Text(item.courseName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Text(item.remainingTextNow)
                                .font(.caption2.monospacedDigit().weight(.semibold))
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }

    private var limitForFamily: Int {
        switch family {
        case .systemSmall: 2
        case .systemMedium: 3
        default: 6
        }
    }

    private func color(for urgency: String) -> Color {
        switch urgency {
        case "critical": return .red
        case "soon": return .orange
        default: return .green
        }
    }
}

@main
struct AssignmentWidget: Widget {
    let kind = "AssignmentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AssignmentProvider()) { entry in
            AssignmentWidgetView(entry: entry)
        }
        .configurationDisplayName("学伴提醒")
        .description("显示近期待完成的学习通作业。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
