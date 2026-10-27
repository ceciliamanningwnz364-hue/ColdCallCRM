import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @State private var period = 7

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Период", selection: $period) {
                    Text("7 дней").tag(7)
                    Text("30 дней").tag(30)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                StatsContent(days: period).id(period)
            }
            .background(AppBackground())
            .navigationTitle("Итоги")
        }
    }
}

struct DayStat: Identifiable {
    let id: Date
    var calls = 0
    var talks = 0
    var leads = 0
    var goal: Int? = nil
}

struct StatsContent: View {
    let days: Int

    @Query private var calls: [CallRecord]
    @Query private var plans: [DayPlan]

    init(days: Int) {
        self.days = days
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) ?? Date.distantPast
        _calls = Query(filter: #Predicate<CallRecord> { $0.date >= start }, sort: \CallRecord.date)
        _plans = Query(filter: #Predicate<DayPlan> { $0.day >= start })
    }

    private func buildStats() -> [DayStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var dict: [Date: DayStat] = [:]
        for offset in 0..<days {
            if let d = cal.date(byAdding: .day, value: -offset, to: today) {
                dict[d] = DayStat(id: d)
            }
        }
        for c in calls {
            let d = cal.startOfDay(for: c.date)
            dict[d]?.calls += 1
            if c.outcome.isConversation { dict[d]?.talks += 1 }
            if c.outcome == .lead { dict[d]?.leads += 1 }
        }
        for p in plans {
            dict[p.day]?.goal = p.callGoal
        }
        return dict.values.sorted { $0.id < $1.id }
    }

    private func percent(_ a: Int, _ b: Int) -> String {
        guard b > 0 else { return "—" }
        return "\(Int((Double(a) / Double(b) * 100).rounded()))%"
    }

    var body: some View {
        let stats = buildStats()
        let totalCalls = stats.reduce(0) { $0 + $1.calls }
        let totalTalks = stats.reduce(0) { $0 + $1.talks }
        let totalLeads = stats.reduce(0) { $0 + $1.leads }
        let goalDays = stats.filter { ($0.goal ?? Int.max) <= $0.calls && $0.goal != nil }.count

        ScrollView {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    tile("Звонков", "\(totalCalls)", Palette.accent)
                    tile("Разговоров", "\(totalTalks)", Palette.violet)
                    tile("Лидов", "\(totalLeads)", Palette.mint)
                    tile("Дней с выполненной целью", "\(goalDays) из \(days)", Palette.orange)
                }

                CardSection("Конверсия") {
                    conversionRow("Звонок → разговор", percent(totalTalks, totalCalls))
                    SoftDivider()
                    conversionRow("Разговор → лид", percent(totalLeads, totalTalks))
                    SoftDivider()
                    conversionRow("Лидов на 100 звонков",
                                  totalCalls == 0 ? "—" : String(format: "%.1f", Double(totalLeads) / Double(totalCalls) * 100))
                }

                CardSection("Звонки по дням") {
                    Chart(stats) { d in
                        BarMark(x: .value("День", d.id, unit: .day),
                                y: .value("Звонки", d.calls))
                            .foregroundStyle(Palette.accent.gradient)
                            .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: days <= 7 ? 1 : 5)) { _ in
                            AxisValueLabel(format: .dateTime.day())
                        }
                    }
                    .frame(height: 180)
                }

                CardSection("По дням") {
                    LazyVStack(spacing: 0) {
                        ForEach(stats.reversed()) { d in
                            dayRow(d)
                            if d.id != stats.first?.id { SoftDivider() }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: Блоки

    private func tile(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .glassCard(cornerRadius: 22)
    }

    private func conversionRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).font(.headline.monospacedDigit())
        }
    }

    private func dayRow(_ d: DayStat) -> some View {
        let hit = d.goal.map { d.calls >= $0 } ?? false
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(d.id.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                Text("разговоров \(d.talks), лидов \(d.leads)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if hit {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.mint)
            }
            Text(d.goal.map { "\(d.calls) / \($0)" } ?? "\(d.calls)")
                .font(.headline.monospacedDigit())
        }
        .padding(.vertical, 8)
    }
}
