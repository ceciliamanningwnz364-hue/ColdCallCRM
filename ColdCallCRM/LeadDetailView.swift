import SwiftUI
import SwiftData

struct LeadDetailView: View {
    @Bindable var lead: Lead

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var showCallForm = false
    @State private var editingCall: CallRecord?
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                actions
                statusCard
                fieldsCard
                nextContactCard
                notesCard
                historyCard
                deleteButton
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .navigationTitle(lead.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCallForm) { CallFormView(lead: lead) }
        .sheet(item: $editingCall) { call in CallFormView(existing: call) }
        .confirmationDialog("Удалить лида?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { deleteLead() }
        } message: {
            Text("Звонки этого лида останутся в журнале.")
        }
    }

    // MARK: Блоки

    private var header: some View {
        VStack(spacing: 10) {
            Text(lead.initials)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(lead.status.color.gradient, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            Text(lead.title).font(.title2.weight(.bold))
            if !lead.name.isEmpty && !lead.company.isEmpty {
                Text(lead.company).foregroundStyle(.secondary)
            }
            StatusPill(status: lead.status)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var actions: some View {
        let telURL = PhoneURL.tel(lead.phone)
        let waURL = PhoneURL.whatsApp(lead.phone)
        return HStack(spacing: 10) {
            ActionButton(title: "Позвонить", icon: "phone.fill", tint: Palette.mint) {
                if let telURL { openURL(telURL) }
            }
            .opacity(telURL == nil ? 0.4 : 1)
            .disabled(telURL == nil)

            ActionButton(title: "WhatsApp", icon: "message.fill", tint: Palette.accent) {
                if let waURL { openURL(waURL) }
            }
            .opacity(waURL == nil ? 0.4 : 1)
            .disabled(waURL == nil)

            ActionButton(title: "Записать", icon: "square.and.pencil", tint: Palette.violet) {
                showCallForm = true
            }
        }
    }

    private var statusCard: some View {
        CardSection("Статус") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LeadStatus.allCases) { s in
                        Button {
                            withAnimation(.snappy) { lead.status = s }
                            Haptics.tap()
                        } label: {
                            Text(s.title)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .foregroundStyle(lead.status == s ? Color.white : Color.secondary)
                                .background(lead.status == s ? s.color.opacity(0.5) : Color.white.opacity(0.08),
                                            in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var fieldsCard: some View {
        CardSection("Контакт") {
            FieldRow(icon: "person.fill", placeholder: "Имя", text: $lead.name, capitalization: .words)
            SoftDivider()
            FieldRow(icon: "building.2.fill", placeholder: "Компания", text: $lead.company, capitalization: .words)
            SoftDivider()
            FieldRow(icon: "phone.fill", placeholder: "Телефон", text: $lead.phone,
                     keyboard: .phonePad, capitalization: .never)
            SoftDivider()
            FieldRow(icon: "envelope.fill", placeholder: "Email", text: $lead.email,
                     keyboard: .emailAddress, capitalization: .never)
            SoftDivider()
            HStack(spacing: 12) {
                Image(systemName: "banknote.fill").foregroundStyle(.secondary).frame(width: 22)
                TextField("Сумма сделки", value: $lead.amount, format: .number)
                    .keyboardType(.decimalPad)
            }
        }
    }

    private var nextContactCard: some View {
        CardSection("Следующий контакт") {
            Toggle("Назначить дату", isOn: Binding(
                get: { lead.nextContact != nil },
                set: { on in
                    lead.nextContact = on
                        ? Calendar.current.date(byAdding: .day, value: 1, to: Date())
                        : nil
                }
            ))
            if lead.nextContact != nil {
                DatePicker("Когда", selection: Binding(
                    get: { lead.nextContact ?? Date() },
                    set: { lead.nextContact = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
            }
        }
    }

    private var notesCard: some View {
        CardSection("Заметки по лиду") {
            TextEditor(text: $lead.note)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
        }
    }

    private var historyCard: some View {
        let history = lead.calls.sorted { $0.date > $1.date }
        return CardSection("История звонков (\(history.count))") {
            if history.isEmpty {
                Text("Звонков пока нет. Нажмите «Записать» после разговора.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(history) { call in
                        Button { editingCall = call } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                CallRow(call: call)
                                Text(call.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 6)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            Label("Удалить лида", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Palette.red)
                .glassCard(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }

    // MARK: Действия

    private func deleteLead() {
        let ctx = context
        let target = lead
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ctx.delete(target)
            try? ctx.save()
        }
    }
}
