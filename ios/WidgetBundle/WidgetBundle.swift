import WidgetKit
import SwiftUI

// MARK: - Widget bundle entry point

@main
struct TidyQuestWidgetBundle: WidgetBundle {
    var body: some Widget {
        TidyQuestWidget()
    }
}

// MARK: - Stub widget (v0.2 placeholder)

struct TidyQuestWidgetEntry: TimelineEntry {
    let date: Date
}

struct TidyQuestWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TidyQuestWidgetEntry {
        TidyQuestWidgetEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TidyQuestWidgetEntry) -> Void) {
        completion(TidyQuestWidgetEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TidyQuestWidgetEntry>) -> Void) {
        let entry = TidyQuestWidgetEntry(date: .now)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct TidyQuestWidget: Widget {
    let kind = "TidyQuestWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TidyQuestWidgetProvider()) { _ in
            Text("TidyQuest — ready")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("TidyQuest")
        .description("Shows today's chore progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
