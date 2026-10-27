import SwiftUI
import SwiftData

/// Обёртка следит за сменой суток: если приложение открыто за полночь — экран пересоздаётся на новый день.
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dayStart = Calendar.current.startOfDay(for: Date())

    var body: some View {
        TodayContent(dayStart: dayStart)
            .id(dayStart)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    let today = Calendar.current.startOfDay(for: Date())
                    if today != dayStart { dayStart = today }
                }
            }
    }
}

struct TodayContent: View {
    let dayStart: Date

    @Environment(\.modelContext) private var context
    @Query private var calls: [CallRecord]
    @Query private var plans: [DayPlan]

    @State private var showNewCall = false
    @State private var showGoals = false
    @State private var formOutcome: CallOutcome = .talked
    @State private var editing: CallRecord?

    init(dayStart: Date) {
        self.dayStart = dayStart
        let end = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(86_400)
        _calls = Query(
            filter: #Predicate<CallRecord> { $0.date >= dayStart && $0.date < end },
            sort: \CallRecord.date,
            order: .reverse
        )
        _plans = Query(filter: #Predicate<DayPlan> { $0.day == dayStart })
    }

    // MARK: Данные

    private var plan: DayPlan? { plans.first }
    private var callGoal: Int { plan?.callGoal ?? 120 }
    private var talkGoal: Int { plan?.talkGoal ?? 30 }
    private var leadGoal: Int { plan?.leadGoal ?? 5 }
    private var talks: Int { calls.reduce(0) { $0 + ($1.outcome.isConversation ? 1 : 0) } }
    private var leadCount: Int { calls.reduce(0) { $0 + ($1.outcome == .lead ? 1 : 0) } }

    private var remainingText: String {
        let left = callGoal - calls.count
        if left > 0 { return "Осталось \(left)" }
        return left == 0 ? "Цель выполнена" : "Перевыполнено на \(-left)"
    }

    private var reachText: String {
        guard !calls.isEmpty else { return "Начните с первого звонка" }
        let pct = Int((Double(talks) / Double(calls.count) * 100).rounded())
        return "Доходит до разговора: \(pct)%"
    }

    // MARK: Экран

    var body: some View {
        NavigationStack {
            List {
                heroCard.listRow(top: 4)
                HStack(spacing: 12) {
                    MiniStatCard(title: "Разговоры", icon: "bubble.left.and.bubble.right.fill",
                                 value: talks, goal: talkGoal, tint: Palette.accent)
                    MiniStatCard(title: "Лиды", icon: "flame.fill",
                                 value: leadCount, goal: leadGoal, tint: Palette.mint)
                }
                .listRow()

                quickRow.listRow()
                newCallButton.listRow()

                Text("Звонки сегодня")
                    .font(.title3.weight(.semibold))
                    .listRow(top: 14, bottom: 4)

                if calls.isEmpty {
                    Text("Пока пусто. После каждого звонка нажмите «Недозвон», «Отказ» или «Разговор» — это одно касание. Подробности добавите через «Записать звонок».")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRow()
                }

                ForEach(calls) { call in
                    Button { editing = call } label: { CallRow(call: call) }
                        .buttonStyle(.plain)
                        .listRow(top: 4, bottom: 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { delete(call) } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Сегодня")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        formOutcome = .talked
                        showNewCall = true
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showNewCall) { CallFormView(outcome: formOutcome) }
            .sheet(item: $editing) { call in CallFormView(existing: call) }
            .sheet(isPresented: $showGoals) {
                if let plan { GoalsSheet(plan: plan) }
            }
            .task { ensurePlan() }
        }
    }

    // MARK: Блоки

    private var heroCard: some View {
        Button { showGoals = true } label: {
            HStack(spacing: 20) {
                ZStack {
                    RingView(progress: Double(calls.count) / Double(max(callGoal, 1)),
                             lineWidth: 16, colors: [Palette.accent, Palette.mint])
                    VStack(spacing: 0) {
                        Text("\(calls.count)")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("из \(callGoal)").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 148, height: 148)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Холодные звонки").font(.headline)
                    Text(remainingText).font(.title3.weight(.semibold)).foregroundStyle(Palette.mint)
                    Text(reachText).font(.footnote).foregroundStyle(.secondary)
                    Label("Изменить цели", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .animation(.snappy, value: calls.count)
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 32)
    }

    private var quickRow: some View {
        HStack(spacing: 10) {
            ActionButton(title: CallOutcome.noAnswer.title, icon: CallOutcome.noAnswer.icon,
                         tint: CallOutcome.noAnswer.color) { quickLog(.noAnswer) }
            ActionButton(title: CallOutcome.declined.title, icon: CallOutcome.declined.icon,
                         tint: CallOutcome.declined.color) { quickLog(.declined) }
            ActionButton(title: CallOutcome.talked.title, icon: CallOutcome.talked.icon,
                         tint: CallOutcome.talked.color) { quickLog(.talked) }
            ActionButton(title: CallOutcome.lead.title, icon: CallOutcome.lead.icon,
                         tint: CallOutcome.lead.color) {
                formOutcome = .lead
                showNewCall = true
            }
        }
    }

    private var newCallButton: some View {
        Button {
            formOutcome = .talked
            showNewCall = true
        } label: {
            Label("Записать звонок с заметкой", systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassCard(cornerRadius: 24, tint: Palette.accent, interactive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: Действия

    private func quickLog(_ outcome: CallOutcome) {
        context.insert(CallRecord(outcome: outcome))
        try? context.save()
        Haptics.tap()
    }

    private func delete(_ call: CallRecord) {
        withAnimation(.snappy) { context.delete(call) }
        try? context.save()
    }

    /// На каждый день создаём план; стартовые цели берутся из предыдущего плана.
    private func ensurePlan() {
        let day = dayStart
        let existing = try? context.fetch(FetchDescriptor<DayPlan>(predicate: #Predicate { $0.day == day }))
        if let existing, !existing.isEmpty { return }

        var descriptor = FetchDescriptor<DayPlan>(sortBy: [SortDescriptor(\.day, order: .reverse)])
        descriptor.fetchLimit = 1
        let last = (try? context.fetch(descriptor))?.first

        context.insert(DayPlan(day: day,
                               callGoal: last?.callGoal ?? 120,
                               talkGoal: last?.talkGoal ?? 30,
                               leadGoal: last?.leadGoal ?? 5))
        try? context.save()
    }
}

// MARK: - Цели дня

struct GoalsSheet: View {
    @Bindable var plan: DayPlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    goalRow("Холодных звонков", icon: "phone.fill", value: $plan.callGoal, step: 10)
                    goalRow("Разговорных", icon: "bubble.left.and.bubble.right.fill", value: $plan.talkGoal, step: 5)
                    goalRow("Лидов", icon: "flame.fill", value: $plan.leadGoal, step: 1)
                } header: {
                    Text("Цели на сегодня")
                } footer: {
                    Text("Завтра цели подставятся сами. Меняйте только если нужен другой план.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Цели дня")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func goalRow(_ title: String, icon: String, value: Binding<Int>, step: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.accent).frame(width: 24)
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            Stepper("", value: value, in: 0...2000, step: step).labelsHidden()
        }
    }
}
