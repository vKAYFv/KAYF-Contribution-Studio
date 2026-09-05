import SwiftUI

struct KCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.06)))
    }
}

struct KSectionHeader: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.semibold))
            if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
        }
    }
}

struct KStatusBadge: View {
    let title: String
    let isReady: Bool
    var body: some View {
        Label(title, systemImage: isReady ? "checkmark.circle.fill" : "circle.dashed")
            .font(.caption.weight(.medium))
            .foregroundStyle(isReady ? Color.green : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("\(title): \(isReady ? "ready" : "not ready")")
    }
}

struct KMetric: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .semibold, design: .rounded)).contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KToolbarButton: View {
    let title: String
    let systemImage: String
    var selected = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: systemImage).labelStyle(.iconOnly) }
            .buttonStyle(.bordered)
            .tint(selected ? .accentColor : nil)
            .help(title)
            .accessibilityLabel(title)
    }
}

struct KEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(message))
    }
}

extension ContributionTheme {
    func color(level: Int, colorScheme: ColorScheme, customPalette: [ThemeColor] = ThemeColor.github) -> Color {
        if self == .custom, customPalette.indices.contains(level) {
            let value = customPalette[level]
            return Color(red: value.red, green: value.green, blue: value.blue, opacity: value.opacity)
        }
        guard level > 0 else { return colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.06) }
        let palette: [Color]
        switch self {
        case .github: palette = [Color(red: 0.05, green: 0.43, blue: 0.20), Color(red: 0.10, green: 0.56, blue: 0.27), Color(red: 0.18, green: 0.70, blue: 0.34), Color(red: 0.23, green: 0.82, blue: 0.43)]
        case .purple: palette = [.purple.opacity(0.35), .purple.opacity(0.55), .purple.opacity(0.75), .purple]
        case .blue: palette = [.blue.opacity(0.35), .blue.opacity(0.55), .blue.opacity(0.75), .blue]
        case .orange: palette = [.orange.opacity(0.35), .orange.opacity(0.55), .orange.opacity(0.75), .orange]
        case .monochrome: palette = [.secondary.opacity(0.35), .secondary.opacity(0.55), .secondary.opacity(0.75), .primary]
        case .custom: palette = [.green.opacity(0.35), .green.opacity(0.55), .green.opacity(0.75), .green]
        }
        return palette[min(3, level - 1)]
    }
}
