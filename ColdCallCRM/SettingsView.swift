import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var shareItem: ShareItem?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { exportCalls() } label: {
                        Label("Экспорт звонков (CSV)", systemImage: "square.and.arrow.up")
                    }
                    Button { exportLeads() } label: {
                        Label("Экспорт лидов (CSV)", systemImage: "square.and.arrow.up.on.square")
                    }
                } header: {
                    Text("Данные")
                } footer: {
                    Text("Файл открывается в Excel, Numbers и Google Таблицах. Все данные хранятся только на этом iPhone.")
                }

                Section("Как считаются звонки") {
                    Text("Звонком считается любая запись: недозвон, секретарь, отказ, разговор, «перезвонить» или лид.")
                    Text("Разговорным считается звонок с результатом «Отказ», «Разговор», «Перезвонить» или «Лид».")
                    Text("Результат «Лид» сразу создаёт карточку в разделе «Лиды». Если номер уже есть в базе, звонок привяжется к существующему лиду.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Section("О приложении") {
                    LabeledContent("Версия", value: appVersion)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Ещё")
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: Экспорт

    private func exportCalls() {
        let descriptor = FetchDescriptor<CallRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let calls = (try? context.fetch(descriptor)) ?? []
        let name = "calls-\(Exporter.fileDate()).csv"
        if let url = Exporter.write(Exporter.callsCSV(calls), name: name) {
            Haptics.success()
            shareItem = ShareItem(url: url)
        }
    }

    private func exportLeads() {
        let descriptor = FetchDescriptor<Lead>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let leads = (try? context.fetch(descriptor)) ?? []
        let name = "leads-\(Exporter.fileDate()).csv"
        if let url = Exporter.write(Exporter.leadsCSV(leads), name: name) {
            Haptics.success()
            shareItem = ShareItem(url: url)
        }
    }
}

// MARK: - CSV

enum Exporter {
    private static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func fileDate() -> String { dateOnly.string(from: Date()) }

    private static func esc(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// BOM + «;» — чтобы русский Excel сразу открыл файл в правильной кодировке и по колонкам.
    static func callsCSV(_ calls: [CallRecord]) -> String {
        var rows = ["Дата;Имя;Компания;Телефон;Результат;Заметка;Лид"]
        for c in calls {
            let fields = [dateTime.string(from: c.date), c.contactName, c.company, c.phone,
                          c.outcome.title, c.note, c.lead?.title ?? ""]
            rows.append(fields.map { esc($0) }.joined(separator: ";"))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    static func leadsCSV(_ leads: [Lead]) -> String {
        var rows = ["Создан;Имя;Компания;Телефон;Email;Статус;Сумма;Следующий контакт;Звонков;Заметка"]
        for l in leads {
            let fields = [dateTime.string(from: l.createdAt), l.name, l.company, l.phone, l.email,
                          l.status.title, String(format: "%.0f", l.amount),
                          l.nextContact.map { dateTime.string(from: $0) } ?? "",
                          String(l.calls.count), l.note]
            rows.append(fields.map { esc($0) }.joined(separator: ";"))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n")
    }

    static func write(_ text: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Системное меню «Поделиться»

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
