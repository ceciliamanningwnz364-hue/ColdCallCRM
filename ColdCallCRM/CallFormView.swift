import SwiftUI
import SwiftData

struct CallFormView: View {
    enum Field: Hashable { case name, company, phone, note }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let existing: CallRecord?
    private let presetLead: Lead?

    @State private var name: String
    @State private var company: String
    @State private var phone: String
    @State private var outcome: CallOutcome
    @State private var note: String
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    init(existing: CallRecord? = nil, lead: Lead? = nil, outcome: CallOutcome = .talked) {
        self.existing = existing
        self.presetLead = lead
        _name = State(initialValue: existing?.contactName ?? lead?.name ?? "")
        _company = State(initialValue: existing?.company ?? lead?.company ?? "")
        _phone = State(initialValue: existing?.phone ?? lead?.phone ?? "")
        _outcome = State(initialValue: existing?.outcome ?? outcome)
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    contactCard
                    outcomeCard
                    noteCard
                    if existing != nil { deleteButton }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle(existing == nil ? "Новый звонок" : "Звонок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focus = nil }
                }
            }
            .confirmationDialog("Удалить звонок?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { deleteExisting() }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: Блоки

    private var contactCard: some View {
        CardSection("Контакт") {
            FieldRow(icon: "person.fill", placeholder: "Имя", text: $name, capitalization: .words)
                .focused($focus, equals: .name)
            SoftDivider()
            FieldRow(icon: "building.2.fill", placeholder: "Компания", text: $company, capitalization: .words)
                .focused($focus, equals: .company)
            SoftDivider()
            HStack(spacing: 8) {
                FieldRow(icon: "phone.fill", placeholder: "Телефон", text: $phone,
                         keyboard: .phonePad, capitalization: .never)
                    .focused($focus, equals: .phone)
                if let url = PhoneURL.tel(phone) {
                    Button { openURL(url) } label: {
                        Image(systemName: "phone.arrow.up.right.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Palette.mint.opacity(0.35), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var outcomeCard: some View {
        CardSection("Результат") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(CallOutcome.allCases) { item in
                    OutcomeChip(outcome: item, selected: outcome == item) {
                        outcome = item
                        Haptics.tap()
                    }
                }
            }
        }
    }

    private var noteCard: some View {
        CardSection("Заметка") {
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Что сказал клиент, возражения, договорённости…")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $note)
                    .focused($focus, equals: .note)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 130)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            Label("Удалить звонок", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Palette.red)
                .glassCard(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }

    // MARK: Действия

    private func save() {
        let record: CallRecord
        if let existing {
            record = existing
        } else {
            record = CallRecord()
            context.insert(record)
        }

        record.contactName = name.trimmed
        record.company = company.trimmed
        record.phone = phone.trimmed
        record.outcome = outcome
        record.note = note.trimmed

        if existing == nil, let presetLead {
            record.lead = presetLead
        }
        // «Лид» автоматически попадает в CRM (ищем по номеру телефона, иначе создаём нового).
        if outcome == .lead && record.lead == nil {
            record.lead = LeadService.findOrCreate(name: record.contactName, company: record.company,
                                                   phone: record.phone, note: record.note, in: context)
        }

        try? context.save()
        Haptics.success()
        dismiss()
    }

    /// Закрываем экран и только потом удаляем объект — иначе SwiftUI может обратиться к уже удалённой модели.
    private func deleteExisting() {
        guard let record = existing else { return }
        let ctx = context
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ctx.delete(record)
            try? ctx.save()
        }
    }
}
