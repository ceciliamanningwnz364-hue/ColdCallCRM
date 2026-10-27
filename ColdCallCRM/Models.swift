import Foundation
import SwiftData
import SwiftUI

// MARK: - Результат звонка

enum CallOutcome: String, CaseIterable, Identifiable {
    case noAnswer, gatekeeper, declined, talked, callback, lead

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noAnswer:   return "Недозвон"
        case .gatekeeper: return "Секретарь"
        case .declined:   return "Отказ"
        case .talked:     return "Разговор"
        case .callback:   return "Перезвонить"
        case .lead:       return "Лид"
        }
    }

    var icon: String {
        switch self {
        case .noAnswer:   return "phone.down.fill"
        case .gatekeeper: return "building.2.fill"
        case .declined:   return "xmark.circle.fill"
        case .talked:     return "bubble.left.and.bubble.right.fill"
        case .callback:   return "clock.fill"
        case .lead:       return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .noAnswer:   return Palette.gray
        case .gatekeeper: return Palette.violet
        case .declined:   return Palette.red
        case .talked:     return Palette.accent
        case .callback:   return Palette.orange
        case .lead:       return Palette.mint
        }
    }

    /// Считается ли звонок «разговорным».
    /// Хотите, чтобы «Отказ» НЕ считался разговором — уберите .declined из списка ниже.
    var isConversation: Bool {
        switch self {
        case .noAnswer, .gatekeeper: return false
        case .declined, .talked, .callback, .lead: return true
        }
    }
}

// MARK: - Статус лида

enum LeadStatus: String, CaseIterable, Identifiable {
    case new, inProgress, meeting, proposal, won, lost

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new:        return "Новый"
        case .inProgress: return "В работе"
        case .meeting:    return "Встреча"
        case .proposal:   return "КП"
        case .won:        return "Сделка"
        case .lost:       return "Потерян"
        }
    }

    var color: Color {
        switch self {
        case .new:        return Palette.accent
        case .inProgress: return Palette.orange
        case .meeting:    return Palette.violet
        case .proposal:   return Palette.pink
        case .won:        return Palette.mint
        case .lost:       return Palette.gray
        }
    }
}

// MARK: - Модели

@Model
final class Lead {
    var createdAt: Date = Date()
    var name: String = ""
    var company: String = ""
    var phone: String = ""
    var email: String = ""
    var note: String = ""
    var statusRaw: String = LeadStatus.new.rawValue
    var amount: Double = 0
    var nextContact: Date? = nil

    @Relationship(deleteRule: .nullify, inverse: \CallRecord.lead)
    var calls: [CallRecord] = []

    init(name: String = "", company: String = "", phone: String = "",
         email: String = "", note: String = "", status: LeadStatus = .new) {
        self.createdAt = Date()
        self.name = name
        self.company = company
        self.phone = phone
        self.email = email
        self.note = note
        self.statusRaw = status.rawValue
    }

    var status: LeadStatus {
        get { LeadStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    var title: String {
        if !name.isEmpty { return name }
        if !company.isEmpty { return company }
        if !phone.isEmpty { return phone }
        return "Без имени"
    }

    var subtitle: String {
        var parts: [String] = []
        if !name.isEmpty && !company.isEmpty { parts.append(company) }
        if !phone.isEmpty { parts.append(phone) }
        return parts.joined(separator: " · ")
    }

    var initials: String {
        let letters = title.split(separator: " ").prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "?" : s
    }
}

@Model
final class CallRecord {
    var date: Date = Date()
    var contactName: String = ""
    var company: String = ""
    var phone: String = ""
    var outcomeRaw: String = CallOutcome.noAnswer.rawValue
    var note: String = ""
    var lead: Lead? = nil

    init(date: Date = Date(), contactName: String = "", company: String = "",
         phone: String = "", outcome: CallOutcome = .noAnswer,
         note: String = "", lead: Lead? = nil) {
        self.date = date
        self.contactName = contactName
        self.company = company
        self.phone = phone
        self.outcomeRaw = outcome.rawValue
        self.note = note
        self.lead = lead
    }

    var outcome: CallOutcome {
        get { CallOutcome(rawValue: outcomeRaw) ?? .noAnswer }
        set { outcomeRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if !contactName.isEmpty { return contactName }
        if !company.isEmpty { return company }
        if !phone.isEmpty { return phone }
        return "Без имени"
    }
}

/// План на конкретный день (цели хранятся по дням, чтобы история была честной).
@Model
final class DayPlan {
    var day: Date = Date()
    var callGoal: Int = 120
    var talkGoal: Int = 30
    var leadGoal: Int = 5

    init(day: Date, callGoal: Int = 120, talkGoal: Int = 30, leadGoal: Int = 5) {
        self.day = day
        self.callGoal = callGoal
        self.talkGoal = talkGoal
        self.leadGoal = leadGoal
    }
}

// MARK: - Сервис лидов

enum LeadService {
    static func digits(_ s: String) -> String { s.filter { $0.isNumber } }

    /// Ищет лида по номеру телефона, иначе создаёт нового.
    static func findOrCreate(name: String, company: String, phone: String,
                             note: String, in context: ModelContext) -> Lead {
        let d = digits(phone)
        if !d.isEmpty,
           let all = try? context.fetch(FetchDescriptor<Lead>()),
           let found = all.first(where: { digits($0.phone) == d }) {
            return found
        }
        let lead = Lead(name: name, company: company, phone: phone, note: note)
        context.insert(lead)
        return lead
    }
}
