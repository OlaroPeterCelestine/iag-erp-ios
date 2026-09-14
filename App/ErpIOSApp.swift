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
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            IagBrandLogo(height: 132, mono: false)
                .padding(.horizontal, 40)
        }
        .preferredColorScheme(.dark)
    }
}

enum IagTheme {
    static let orange = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    static let orangeDeep = Color(red: 234 / 255, green: 88 / 255, blue: 12 / 255)
    static let success = Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255)
    static let canvas = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let muted = Color.secondary
    static let radius: CGFloat = 22
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
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(IagTheme.orange)
            Text("IAG")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct IagIconWell: View {
    var systemName: String
    var color: Color = IagTheme.orange
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 40, height: 40)
    }
}

struct StatusPill: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(statusColor(text))
            .background(statusColor(text).opacity(0.12), in: Capsule())
    }
}

struct DeskRow: View {
    var title: String
    var subtitle: String
    var systemName: String = "square.grid.2x2"
    var color: Color = IagTheme.orange
    var status: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            IagIconWell(systemName: systemName, color: color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
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
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(.subheadline.weight(.semibold))
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
            .padding(16)
    }
}

struct IagGrouped<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
    }
}

struct IagRowDivider: View {
    var body: some View {
        Divider().padding(.leading, 68)
    }
}

struct AppTile: View {
    let app: SuiteApp
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [iagColor(app.color), iagColor(app.color).opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 68)
                .overlay {
                    Image(systemName: app.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            Text(app.label)
                .font(.caption.weight(.semibold))
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
        let tint = iagColor(action.color)
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: action.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
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
        let tint = iagColor(action.color)
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: action.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red, in: Capsule())
                        .offset(x: 14, y: -10)
                }
            }
            Text(action.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct KpiChip: View {
    let kpi: Kpi
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kpi.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(kpi.value)
                .font(.subheadline.weight(.semibold))
            Text(kpi.hint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(minWidth: 136, alignment: .leading)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
    }
}

struct WelcomeCard: View {
    var name: String
    var subtitle: String
    var stats: [WelcomeStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(iagGreeting())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !stats.isEmpty {
                HStack(spacing: 10) {
                    ForEach(stats) { stat in
                        let hot = stat.id == "todo" && stat.value != "0"
                        VStack(spacing: 4) {
                            Text(stat.value)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(hot ? IagTheme.orange : .primary)
                            Text(stat.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            hot ? IagTheme.orange.opacity(0.12) : IagTheme.card,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }
                }
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
