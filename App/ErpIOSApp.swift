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

    var body: some View {
        let _ = box.tick
        Group {
            if box.store.isSignedIn {
                ShellView()
                    .preferredColorScheme(box.store.themeMode == "dark" ? .dark : box.store.themeMode == "light" ? .light : nil)
            } else {
                LoginView()
                    .preferredColorScheme(.light)
            }
        }
    }
}

enum IagTheme {
    static let orange = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    static let orangeDeep = Color(red: 234 / 255, green: 88 / 255, blue: 12 / 255)
    static let success = Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255)
    static let canvas = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let muted = Color.secondary
    static let radius: CGFloat = 16
}

func iagGreeting() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 12 { return "Good morning" }
    if hour < 17 { return "Good afternoon" }
    return "Good evening"
}

func iagColor(_ hex: UInt32) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
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
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(.caption.weight(.semibold))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IagIconWell(systemName: app.icon, color: iagColor(app.color))
            VStack(alignment: .leading, spacing: 4) {
                Text(app.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(app.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
    }
}

struct QuickActionButton: View {
    let action: QuickAction
    var badge: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(IagTheme.orange.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: action.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(IagTheme.orange)
                    }
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .padding(.horizontal, 3)
                        .background(Color.red, in: Capsule())
                        .offset(x: 4, y: -2)
                }
            }
            Text(action.label)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 72)
        }
        .frame(maxWidth: .infinity)
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(iagGreeting()), \(name)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                IagMark(size: 36)
            }
            if !stats.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                        if index > 0 {
                            Rectangle()
                                .fill(.white.opacity(0.22))
                                .frame(width: 1, height: 28)
                                .padding(.horizontal, 8)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.value)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text(stat.label)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [IagTheme.orange, IagTheme.orangeDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous)
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
