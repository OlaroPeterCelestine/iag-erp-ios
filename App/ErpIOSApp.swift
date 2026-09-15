import SwiftUI
import UIKit
import ErpCore

@main
struct ErpIOSApp: App {
    @StateObject private var box = StoreBox()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(box)
                .tint(IagTheme.orange)
        }
    }
}

final class StoreBox: ObservableObject {
    let store: ErpStore
    @Published var tick: Int = 0

    init() {
        let persistence = UserDefaultsStore()
        let origin = ErpConfig.origin(from: persistence)
        let store = ErpStore(persistence: persistence, api: ErpApi(origin: origin))
        store.load()
        self.store = store
        store.addListener { [weak self] in
            DispatchQueue.main.async { self?.tick += 1 }
        }
        Task { await store.resumeRemoteSession() }
    }
}

struct RootView: View {
    @EnvironmentObject var box: StoreBox
    @State private var showSplash = true

    var body: some View {
        let _ = box.tick
        ZStack {
            Group {
                if box.store.isSignedIn {
                    ShellView()
                        .preferredColorScheme(box.store.themeMode == "dark" ? .dark : box.store.themeMode == "light" ? .light : nil)
                } else {
                    LoginView()
                        .preferredColorScheme(.light)
                }
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            }
        }
    }
}

struct SplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color(red: 10 / 255, green: 10 / 255, blue: 12 / 255).ignoresSafeArea()
            IagBrandLogo(height: 96, mono: false)
                .padding(.horizontal, 56)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.96)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { appear = true }
        }
    }
}

enum IagTheme {
    /// Brand accent — used sparingly (tint, hot todo, primary CTA).
    static let orange = Color(red: 232 / 255, green: 104 / 255, blue: 32 / 255)
    static let orangeDeep = Color(red: 194 / 255, green: 78 / 255, blue: 16 / 255)
    static let ink = Color(red: 17 / 255, green: 17 / 255, blue: 19 / 255)
    static let success = Color(red: 22 / 255, green: 128 / 255, blue: 92 / 255)
    static let canvas = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let hairline = Color.primary.opacity(0.08)
    static let muted = Color.secondary
    static let radius: CGFloat = 16
    static let radiusSm: CGFloat = 12
}

func iagGreeting() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 12 { return "Good morning" }
    if hour < 17 { return "Good afternoon" }
    return "Good evening"
}

func iagColor(_ hex: UInt32) -> Color {
    let rgb = hex & 0x00FFFFFF
    return Color(
        red: Double((rgb >> 16) & 0xFF) / 255,
        green: Double((rgb >> 8) & 0xFF) / 255,
        blue: Double(rgb & 0xFF) / 255
    )
}

func statusColor(_ status: String) -> Color {
    let s = status.lowercased()
    if ["paid", "approved", "active", "released", "closed", "verified", "present", "posted", "cleared"].contains(where: { s.contains($0) }) {
        return IagTheme.success
    }
    if ["overdue", "reject", "void", "cancel", "outside"].contains(where: { s.contains($0) }) {
        return Color.red
    }
    if ["pending", "open", "draft", "held", "flagged", "submitted"].contains(where: { s.contains($0) }) {
        return IagTheme.orange
    }
    return IagTheme.muted
}

struct IagBrandLogo: View {
    var height: CGFloat = 128
    var mono: Bool = false
    var body: some View {
        Image(mono ? "IagLogoMono" : "IagLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(maxWidth: 280, maxHeight: height)
            .accessibilityLabel("Inspire Africa Group")
    }
}

struct IagMark: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(IagTheme.ink)
            Text("IAG")
                .font(.system(size: size * 0.26, weight: .semibold, design: .default))
                .tracking(0.6)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct IagIconWell: View {
    var systemName: String
    var color: Color = IagTheme.ink
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: IagTheme.radiusSm, style: .continuous)
                .fill(Color.primary.opacity(0.05))
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color.opacity(0.9))
        }
        .frame(width: 38, height: 38)
    }
}

struct StatusPill: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(statusColor(text))
            .background(statusColor(text).opacity(0.1), in: Capsule())
    }
}

struct DeskRow: View {
    var title: String
    var subtitle: String
    var systemName: String = "square.grid.2x2"
    var color: Color = IagTheme.ink
    var status: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            IagIconWell(systemName: systemName, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if let status { StatusPill(text: status) }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct IagSectionHeader: View {
    var title: String
    var accessory: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(IagTheme.orange)
            }
        }
    }
}

struct IagEmptyHint: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
    }
}

struct IagGrouped<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                    .stroke(IagTheme.hairline, lineWidth: 1)
            )
    }
}

struct IagRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(IagTheme.hairline)
            .frame(height: 1)
            .padding(.leading, 66)
    }
}

struct AppTile: View {
    let app: SuiteApp
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                .fill(IagTheme.card)
                .frame(height: 64)
                .overlay {
                    Image(systemName: app.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(IagTheme.ink)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                        .stroke(IagTheme.hairline, lineWidth: 1)
                )
            Text(app.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    var badge: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: IagTheme.radiusSm, style: .continuous)
                    .fill(IagTheme.card)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: action.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(IagTheme.ink)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: IagTheme.radiusSm, style: .continuous)
                            .stroke(IagTheme.hairline, lineWidth: 1)
                    )
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(IagTheme.orange, in: Capsule())
                        .offset(x: 6, y: -4)
                }
            }
            Text(action.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: 76)
        }
        .frame(width: 76)
    }
}

struct TodayActionCard: View {
    let action: QuickAction
    var badge: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: action.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(IagTheme.ink)
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(IagTheme.orange, in: Capsule())
                        .offset(x: 14, y: -10)
                }
            }
            Text(action.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                .stroke(IagTheme.hairline, lineWidth: 1)
        )
    }
}

struct KpiChip: View {
    let kpi: Kpi
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kpi.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(kpi.value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(kpi.hint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(minWidth: 140, alignment: .leading)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                .stroke(IagTheme.hairline, lineWidth: 1)
        )
    }
}

struct WelcomeCard: View {
    var name: String
    var subtitle: String
    var stats: [WelcomeStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(iagGreeting().uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.1)
                Text(name)
                    .font(.system(size: 34, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !stats.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        let hot = stat.id == "todo" && stat.value != "0"
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.value)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(hot ? IagTheme.orange : .primary)
                            Text(stat.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index < stats.count - 1 {
                            Rectangle()
                                .fill(IagTheme.hairline)
                                .frame(width: 1, height: 36)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                        .stroke(IagTheme.hairline, lineWidth: 1)
                )
            }
        }
    }
}

struct GreetingHeader: View {
    var name: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(iagGreeting()), \(name)")
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func iagCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
    }

    func iagCard() -> some View {
        self.background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
    }
}
