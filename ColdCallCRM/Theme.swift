import SwiftUI
import UIKit

// MARK: - Палитра

enum Palette {
    static let accent = Color(red: 0.30, green: 0.62, blue: 1.00)
    static let mint   = Color(red: 0.25, green: 0.86, blue: 0.72)
    static let violet = Color(red: 0.58, green: 0.45, blue: 1.00)
    static let orange = Color(red: 1.00, green: 0.62, blue: 0.25)
    static let pink   = Color(red: 1.00, green: 0.38, blue: 0.55)
    static let red    = Color(red: 1.00, green: 0.35, blue: 0.38)
    static let gray   = Color(red: 0.60, green: 0.63, blue: 0.70)
    static let top    = Color(red: 0.05, green: 0.07, blue: 0.17)
    static let bottom = Color(red: 0.02, green: 0.03, blue: 0.09)
}

/// Тёмный градиентный фон со светящимися пятнами — под ним стекло красиво преломляется.
/// Только градиенты (без blur) — почти ничего не стоит GPU.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.top, Palette.bottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.accent.opacity(0.42), .clear],
                           center: UnitPoint(x: 0.12, y: 0.04), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Palette.violet.opacity(0.32), .clear],
                           center: UnitPoint(x: 0.98, y: 0.38), startRadius: 0, endRadius: 360)
            RadialGradient(colors: [Palette.mint.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.18, y: 0.98), startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Хелперы

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

enum PhoneURL {
    static func tel(_ phone: String) -> URL? {
        let cleaned = phone.filter { $0.isNumber || $0 == "+" }
        guard !cleaned.isEmpty else { return nil }
        return URL(string: "tel://\(cleaned)")
    }

    static func whatsApp(_ phone: String) -> URL? {
        var digits = phone.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        if digits.count == 11 && digits.hasPrefix("8") { digits = "7" + digits.dropFirst() }
        return URL(string: "https://wa.me/\(digits)")
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension View {
    /// Строка List без фона, разделителей и с ровными отступами.
    func listRow(top: CGFloat = 6, bottom: CGFloat = 6) -> some View {
        self.listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
    }

    /// Лёгкая полупрозрачная карточка для длинных списков (дешёвая для GPU).
    func softCard(cornerRadius: CGFloat = 20) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(shape.fill(Color.white.opacity(0.07)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 0.7))
    }

    /// Liquid Glass (iOS 26+) с аккуратным откатом на материал для старых iOS.
    func glassCard(cornerRadius: CGFloat = 26, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassBackground(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive
        ))
    }
}

struct GlassBackground<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color?
    var interactive: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(Self.makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func makeGlass(tint: Color?, interactive: Bool) -> Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint.opacity(0.55)) }
        if interactive { glass = glass.interactive() }
        return glass
    }
    #endif

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        content
            .background(shape.fill(.ultraThinMaterial))
            .background(shape.fill((tint ?? Color.clear).opacity(0.25)))
            .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 0.8))
    }
}

// MARK: - Компоненты

/// Кольцо прогресса — главный визуальный акцент приложения.
struct RingView: View {
    var progress: Double
    var lineWidth: CGFloat = 16
    var colors: [Color]

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.10), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(colors: colors, center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: (colors.last ?? Palette.accent).opacity(0.45), radius: 8)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: progress)
    }
}

struct ProgressBar: View {
    var progress: Double
    var tint: Color

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            GeometryReader { geo in
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }
}

struct MiniStatCard: View {
    let title: String
    let icon: String
    let value: Int
    let goal: Int
    let tint: Color

    private var progress: Double { goal > 0 ? Double(value) / Double(goal) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(tint)
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("из \(goal)").font(.subheadline).foregroundStyle(.secondary)
            }
            ProgressBar(progress: progress, tint: tint)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .animation(.snappy, value: value)
    }
}

/// Стеклянная кнопка с иконкой и подписью.
struct ActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 21, weight: .semibold))
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 68)
            .glassCard(cornerRadius: 22, tint: tint, interactive: true)
        }
        .buttonStyle(.plain)
    }
}

struct OutcomeChip: View {
    let outcome: CallOutcome
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: outcome.icon).font(.system(size: 20, weight: .semibold))
                Text(outcome.title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(selected ? outcome.color.opacity(0.42) : Color.white.opacity(0.07), in: shape)
            .overlay(shape.strokeBorder(selected ? outcome.color : Color.white.opacity(0.10),
                                        lineWidth: selected ? 1.5 : 0.7))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: selected)
    }
}

struct StatusPill: View {
    let status: LeadStatus

    var body: some View {
        Text(status.title)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.18), in: Capsule())
    }
}

/// Стеклянная секция с заголовком.
struct CardSection<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }
}

struct FieldRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
        }
        .padding(.vertical, 2)
    }
}

struct SoftDivider: View {
    var body: some View { Divider().overlay(Color.white.opacity(0.08)) }
}

/// Строка звонка (используется в «Сегодня» и в карточке лида).
struct CallRow: View {
    let call: CallRecord

    private var subtitle: String {
        var parts = [call.outcome.title]
        let hasName = !call.contactName.isEmpty
        let hasCompany = !call.company.isEmpty
        if hasName && hasCompany { parts.append(call.company) }
        if !call.phone.isEmpty && (hasName || hasCompany) { parts.append(call.phone) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: call.outcome.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(call.outcome.color)
                .frame(width: 36, height: 36)
                .background(call.outcome.color.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(call.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if call.lead != nil {
                        Image(systemName: "flame.fill").font(.caption2).foregroundStyle(Palette.mint)
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !call.note.isEmpty {
                    Text(call.note).font(.caption).foregroundStyle(.secondary.opacity(0.85)).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(call.date, format: .dateTime.hour().minute())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(cornerRadius: 18)
        .contentShape(Rectangle())
    }
}
