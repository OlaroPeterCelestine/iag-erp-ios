import SwiftUI
import UIKit
import ErpCore

@main
struct ErpIOSApp: App {
    @StateObject private var box = StoreBox()

    init() {
        let canvas = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.09, blue: 0.08, alpha: 1)
                : UIColor(red: 244 / 255, green: 247 / 255, blue: 245 / 255, alpha: 1)
        }
        let card = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white
        }
        UITableView.appearance().backgroundColor = canvas
        UICollectionView.appearance().backgroundColor = canvas
        UITableViewCell.appearance().backgroundColor = card
        UICollectionViewCell.appearance().backgroundColor = card
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(box)
                .tint(IagTheme.leaf)
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
    static let leaf = Color(red: 23 / 255, green: 122 / 255, blue: 74 / 255)
    static let canvas = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.09, blue: 0.08, alpha: 1)
            : UIColor(red: 244 / 255, green: 247 / 255, blue: 245 / 255, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white
    })
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
        return IagTheme.leaf
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
    var color: Color = IagTheme.leaf
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.14))
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
    }
}

struct IagAvatar: View {
    var name: String
    var size: CGFloat = 52
    var body: some View {
        let letter = name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "I"
        ZStack {
            Circle().fill(IagTheme.leaf.opacity(0.16))
            Text(letter)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(IagTheme.leaf)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
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
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IagTheme.leaf)
            }
        }
    }
}

struct IagEmptyHint: View {
    var text: String
    var systemName: String = "magnifyingglass"
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
    }
}

struct IagGrouped<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
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

    private var tint: Color { iagColor(app.color) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: app.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(height: 72)
            Text(app.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
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

    private var tint: Color { iagColor(action.color) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: action.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(tint)
                            .symbolRenderingMode(.hierarchical)
                    }
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(IagTheme.leaf, in: Capsule())
                        .offset(x: 8, y: -6)
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

    private var tint: Color { iagColor(action.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IagIconWell(systemName: action.icon, color: tint, size: 40)
                Spacer()
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(IagTheme.leaf, in: Capsule())
                }
            }
            Text(action.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

struct KpiChip: View {
    let kpi: Kpi
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(IagTheme.leaf)
                .frame(height: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(kpi.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(kpi.value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(kpi.hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(14)
        }
        .frame(minWidth: 148, alignment: .leading)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                IagAvatar(name: name)
                VStack(alignment: .leading, spacing: 2) {
                    Text(iagGreeting())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(IagTheme.leaf)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            if !stats.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        let hot = stat.id == "todo" && stat.value != "0"
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stat.value)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(hot ? IagTheme.leaf : .primary)
                            Text(stat.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if index < stats.count - 1 {
                            Rectangle()
                                .fill(IagTheme.hairline)
                                .frame(width: 1, height: 32)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: IagTheme.radiusSm, style: .continuous))
            }
        }
        .padding(16)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
                .stroke(IagTheme.hairline, lineWidth: 1)
        )
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

struct IagPageTitle: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Pins the page name on the navigation bar, with an optional context line under it.
    func iagBar(_ title: String, subtitle: String? = nil) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(IagTheme.card, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    IagPageTitle(title: title, subtitle: subtitle)
                }
            }
    }

    func iagCanvas() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
            .tint(IagTheme.leaf)
    }

    func iagPage() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
    }

    func iagCard() -> some View {
        self.background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
    }
}
