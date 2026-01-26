import WidgetKit
import SwiftUI

struct NoteCalWidget: Widget {
    let kind: String = "NoteCalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoteCalWidgetProvider()) { entry in
            NoteCalWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("NoteCal")
        .description("View your daily calories, exercises, and notes.")
        .supportedFamilies([.systemSmall])
    }
}

struct NoteCalWidgetEntry: TimelineEntry {
    let date: Date
    let todayCaloriesConsumed: Int
    let todayCaloriesGoal: Int
    let todayMealsLogged: Bool
    let todayLastExerciseTitle: String
    let todayHasNote: Bool
    let weekLoggedDays: Int
}

struct NoteCalWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoteCalWidgetEntry {
        NoteCalWidgetEntry(
            date: Date(),
            todayCaloriesConsumed: 1650,
            todayCaloriesGoal: 2200,
            todayMealsLogged: true,
            todayLastExerciseTitle: "Push Day",
            todayHasNote: true,
            weekLoggedDays: 5
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NoteCalWidgetEntry) -> ()) {
        let entry = loadWidgetData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoteCalWidgetEntry>) -> ()) {
        let entry = loadWidgetData()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func loadWidgetData() -> NoteCalWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.mertsavaser.notecal")
        guard let dataString = defaults?.string(forKey: "widgetData"),
              let data = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return NoteCalWidgetEntry(
                date: Date(),
                todayCaloriesConsumed: 0,
                todayCaloriesGoal: 2000,
                todayMealsLogged: false,
                todayLastExerciseTitle: "—",
                todayHasNote: false,
                weekLoggedDays: 0
            )
        }

        return NoteCalWidgetEntry(
            date: Date(),
            todayCaloriesConsumed: json["todayCaloriesConsumed"] as? Int ?? 0,
            todayCaloriesGoal: json["todayCaloriesGoal"] as? Int ?? 2000,
            todayMealsLogged: json["todayMealsLogged"] as? Bool ?? false,
            todayLastExerciseTitle: json["todayLastExerciseTitle"] as? String ?? "—",
            todayHasNote: json["todayHasNote"] as? Bool ?? false,
            weekLoggedDays: json["weekLoggedDays"] as? Int ?? 0
        )
    }
}

struct NoteCalWidgetEntryView: View {
    var entry: NoteCalWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text("Today")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Calories remaining
            let remaining = entry.todayCaloriesGoal - entry.todayCaloriesConsumed
            Text("\(remaining) kcal")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(remaining >= 0 ? .primary : .red)
            
            Spacer()
            
            // Last exercise or "No exercise today"
            if entry.todayLastExerciseTitle != "—" {
                let exerciseTitle = entry.todayLastExerciseTitle
                // Try to extract kcal if present (format: "Title (600 kcal)")
                let parts = exerciseTitle.components(separatedBy: " (")
                let titleOnly = parts[0]
                let kcalPart = parts.count > 1 ? parts[1].replacingOccurrences(of: " kcal)", with: "") : nil
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleOnly)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if let kcal = kcalPart {
                        Text("\(kcal) kcal")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No exercise today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Note icon if exists
            if entry.todayHasNote {
                HStack {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
    }
}

#Preview(as: .systemSmall) {
    NoteCalWidget()
} timeline: {
    NoteCalWidgetEntry(
        date: Date(),
        todayCaloriesConsumed: 1650,
        todayCaloriesGoal: 2200,
        todayMealsLogged: true,
        todayLastExerciseTitle: "Push Day (600 kcal)",
        todayHasNote: true,
        weekLoggedDays: 5
    )
}
