import SwiftUI

/// Browse the journal by month — a calendar grid where written days carry a
/// leaf-green dot; tap a day to read what was written.
struct CalendarBrowse: View {
    let entries: [Entry]
    @State private var month: Date = CalendarBrowse.startOfMonth(.now)
    @State private var selectedDay: Date?

    private let cal = Calendar.current

    /// Entries keyed by the start of their day.
    private var byDay: [Date: [Entry]] {
        Dictionary(grouping: entries) { cal.startOfDay(for: $0.createdAt) }
    }

    private var dayEntries: [Entry] {
        guard let day = selectedDay else { return [] }
        return (byDay[day] ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(spacing: 18) {
                    monthHeader
                    grid
                    if let day = selectedDay {
                        Divider().overlay(Paper.line)
                        Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .sectionLabel()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if dayEntries.isEmpty {
                            Text("Nothing written this day.")
                                .font(.calloutSerif).foregroundStyle(Paper.inkFaint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(dayEntries) { entry in
                                NavigationLink(value: entry) {
                                    EntryRow(entry: entry).card()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left").foregroundStyle(Paper.accent)
            }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.display(22)).foregroundStyle(Paper.ink)
            Spacer()
            Button { step(1) } label: {
                Image(systemName: "chevron.right").foregroundStyle(Paper.accent)
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s).font(.label).foregroundStyle(Paper.inkFaint)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let count = byDay[cal.startOfDay(for: day)]?.count ?? 0
        let isSelected = selectedDay == cal.startOfDay(for: day)
        let isToday = cal.isDateInToday(day)
        return Button {
            Haptics.tap()
            let start = cal.startOfDay(for: day)
            selectedDay = (selectedDay == start) ? nil : start
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.figure(15))
                    .foregroundStyle(isSelected ? Paper.bg : (isToday ? Paper.accent : Paper.ink))
                Circle()
                    .fill(count > 0 ? Paper.accent : .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Paper.ink : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: date helpers

    private var isCurrentMonth: Bool {
        cal.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private var weekdaySymbols: [String] {
        let syms = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(syms[first...] + syms[..<first])
    }

    /// Day slots for the grid: leading nils pad to the first weekday.
    private var days: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (weekdayOfFirst - cal.firstWeekday + 7) % 7
        var slots: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in range {
            if let d = cal.date(byAdding: .day, value: offset - 1, to: firstOfMonth) {
                slots.append(d)
            }
        }
        return slots
    }

    private func step(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) {
                month = CalendarBrowse.startOfMonth(m)
                selectedDay = nil
            }
        }
    }

    static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }
}
