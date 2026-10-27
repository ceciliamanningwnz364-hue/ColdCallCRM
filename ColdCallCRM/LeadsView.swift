import SwiftUI
import SwiftData

struct LeadsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Query(sort: \Lead.createdAt, order: .reverse) private var leads: [Lead]

    @State private var path: [Lead] = []
    @State private var search = ""
    @State private var filter: LeadStatus? = nil
    @State private var showNew = false

    private var filtered: [Lead] {
        leads.filter { lead in
            let statusOK = filter == nil || lead.status == filter
            let searchOK = search.isEmpty
                || lead.name.localizedCaseInsensitiveContains(search)
                || lead.company.localizedCaseInsensitiveContains(search)
                || lead.phone.contains(search)
            return statusOK && searchOK
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                filterChips.listRow(top: 4)

                if filtered.isEmpty {
                    ContentUnavailableView(
                        leads.isEmpty ? "Лидов пока нет" : "Ничего не найдено",
                        systemImage: "flame",
                        description: Text(leads.isEmpty
                                          ? "Отметьте звонок как «Лид» или добавьте контакт кнопкой +."
                                          : "Измените поиск или фильтр.")
                    )
                    .listRow()
                }

                ForEach(filtered) { lead in
                    Button { path.append(lead) } label: { LeadRow(lead: lead) }
                        .buttonStyle(.plain)
                        .listRow(top: 4, bottom: 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { delete(lead) } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if let url = PhoneURL.tel(lead.phone) {
                                Button { openURL(url) } label: {
                                    Label("Позвонить", systemImage: "phone.fill")
                                }
                                .tint(Palette.mint)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Лиды")
            .searchable(text: $search, prompt: "Имя, компания, телефон")
            .navigationDestination(for: Lead.self) { LeadDetailView(lead: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showNew) { LeadFormSheet() }
        }
    }

    // MARK: Фильтры

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Все", nil)
                ForEach(LeadStatus.allCases) { status in
                    chip(status.title, status)
                }
            }
        }
    }

    private func count(_ status: LeadStatus?) -> Int {
        guard let status else { return leads.count }
        return leads.filter { $0.status == status }.count
    }

    private func chip(_ title: String, _ status: LeadStatus?) -> some View {
        let selected = filter == status
        return Button {
            withAnimation(.snappy) { filter = status }
            Haptics.tap()
        } label: {
            Text("\(title) \(count(status))")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .background(selected ? (status?.color ?? Palette.accent).opacity(0.5) : Color.white.opacity(0.08),
                            in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func delete(_ lead: Lead) {
        withAnimation(.snappy) { context.delete(lead) }
        try? context.save()
    }
}

// MARK: - Строка лида

struct LeadRow: View {
    let lead: Lead

    var body: some View {
        HStack(spacing: 12) {
            Text(lead.initials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(lead.status.color.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(lead.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                if !lead.subtitle.isEmpty {
                    Text(lead.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if let next = lead.nextContact {
                    Label(next.formatted(date: .abbreviated, time: .shortened), systemImage: "bell.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(next < Date() ? Palette.red : Palette.orange)
                }
            }
            Spacer(minLength: 8)
            StatusPill(status: lead.status)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(cornerRadius: 20)
        .contentShape(Rectangle())
    }
}

// MARK: - Новый лид

struct LeadFormSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var company = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var note = ""
    @State private var status: LeadStatus = .new

    private var canSave: Bool {
        !(name.trimmed.isEmpty && company.trimmed.isEmpty && phone.trimmed.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CardSection("Контакт") {
                        FieldRow(icon: "person.fill", placeholder: "Имя", text: $name, capitalization: .words)
                        SoftDivider()
                        FieldRow(icon: "building.2.fill", placeholder: "Компания", text: $company, capitalization: .words)
                        SoftDivider()
                        FieldRow(icon: "phone.fill", placeholder: "Телефон", text: $phone,
                                 keyboard: .phonePad, capitalization: .never)
                        SoftDivider()
                        FieldRow(icon: "envelope.fill", placeholder: "Email", text: $email,
                                 keyboard: .emailAddress, capitalization: .never)
                    }

                    CardSection("Статус") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(LeadStatus.allCases) { s in
                                    Button { status = s; Haptics.tap() } label: {
                                        Text(s.title)
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .foregroundStyle(status == s ? Color.white : Color.secondary)
                                            .background(status == s ? s.color.opacity(0.5) : Color.white.opacity(0.08),
                                                        in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    CardSection("Заметка") {
                        TextEditor(text: $note)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Новый лид")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.disabled(!canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func save() {
        let lead = Lead(name: name.trimmed, company: company.trimmed, phone: phone.trimmed,
                        email: email.trimmed, note: note.trimmed, status: status)
        context.insert(lead)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
