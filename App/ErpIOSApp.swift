import SwiftUI
import UIKit
import ErpCore

@main
struct ErpIOSApp: App {
    @StateObject private var box = StoreBox()

    init() {
        let canvas = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
                : UIColor(red: 248 / 255, green: 248 / 255, blue: 247 / 255, alpha: 1)
        }
        let card = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
                : .white
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
    /// Brand accent — used sparingly (tint, hot todo, primary CTA).
    static let orange = Color(red: 232 / 255, green: 104 / 255, blue: 32 / 255)
    static let orangeDeep = Color(red: 194 / 255, green: 78 / 255, blue: 16 / 255)
    static let ink = Color(red: 17 / 255, green: 17 / 255, blue: 19 / 255)
    static let success = Color(red: 22 / 255, green: 128 / 255, blue: 92 / 255)
    static let leaf = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.84, blue: 0.64, alpha: 1)
            : UIColor(red: 23 / 255, green: 122 / 255, blue: 74 / 255, alpha: 1)
    })
    static let onLeaf = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.14, blue: 0.08, alpha: 1)
            : .white
    })
    static let canvas = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
            : UIColor(red: 248 / 255, green: 248 / 255, blue: 247 / 255, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
            : .white
    })
    static let hairline = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.06)
    })
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

func entityIcon(_ name: String) -> String {
    let s = name.lowercased()
    if s.contains("clock") || s.contains("punch") || s.contains("attendance") { return "clock" }
    if s.contains("leave") || s.contains("holiday") { return "airplane" }
    if s.contains("payslip") || s.contains("payroll") || s.contains("remittance") { return "banknote" }
    if s.contains("employee") || s.contains("onboarding") || s.contains("job position") { return "person.text.rectangle" }
    if s.contains("customer") || s.contains("portal") { return "person.crop.circle" }
    if s.contains("supplier") { return "person.2" }
    if s.contains("lead") { return "person.badge.plus" }
    if s.contains("opportunit") { return "target" }
    if s.contains("contact") || s.contains("account") && s.contains("crm") { return "person.crop.rectangle" }
    if s.contains("invoice") || s.contains("credit note") || s.contains("debit note") { return "doc.text" }
    if s.contains("quote") { return "doc.plaintext" }
    if s.contains("sales order") || s.contains("distribution order") { return "bag" }
    if s.contains("purchase order") { return "cart" }
    if s.contains("goods receipt") || s.contains("grn") { return "shippingbox" }
    if s.contains("receipt") { return "arrow.down.circle" }
    if s.contains("payment") || s.contains("ipc") { return "arrow.up.circle" }
    if s.contains("claim") { return "receipt" }
    if s.contains("journal") || s.contains("ledger") || s.contains("trial balance") || s.contains("chart of accounts") { return "book.closed" }
    if s.contains("bank") || s.contains("reconcil") || s.contains("transfer") { return "building.columns" }
    if s.contains("balance sheet") || s.contains("profit") || s.contains("cash flow") || s.contains("report") || s.contains("aged") || s.contains("budget") || s.contains("forecast") { return "chart.bar" }
    if s.contains("warehouse") || s.contains("stock") || s.contains("inventory") || s.contains("item") || s.contains("kit") { return "cube.box" }
    if s.contains("roast") { return "flame" }
    if s.contains("machine") || s.contains("batch") || s.contains("bill of material") || s.contains("production") || s.contains("yield") || s.contains("downtime") { return "gearshape.2" }
    if s.contains("vehicle") || s.contains("driver") || s.contains("trip") || s.contains("fleet") { return "car" }
    if s.contains("fuel") { return "fuelpump" }
    if s.contains("maintenance") || s.contains("service reminder") { return "wrench.and.screwdriver" }
    if s.contains("gate") { return "lock.open" }
    if s.contains("visitor") { return "person.badge.key" }
    if s.contains("incident") || s.contains("non-conformance") || s.contains("complaint") { return "exclamationmark.triangle" }
    if s.contains("contract") || s.contains("bond") || s.contains("amendment") { return "signature" }
    if s.contains("project") || s.contains("gantt") || s.contains("variation") { return "briefcase" }
    if s.contains("folder") || s.contains("cabinet") { return "folder" }
    if s.contains("document") || s.contains("file") || s.contains("version") || s.contains("attachment") { return "doc" }
    if s.contains("shipment") || s.contains("dispatch") || s.contains("delivery") || s.contains("route") || s.contains("carrier") || s.contains("picking") || s.contains("packing") { return "box.truck" }
    if s.contains("lab") || s.contains("sample") || s.contains("experiment") || s.contains("formulation") || s.contains("sensory") { return "flask" }
    if s.contains("quality") || s.contains("inspection") || s.contains("capa") || s.contains("release") { return "checkmark.seal" }
    if s.contains("pos") || s.contains("ticket") || s.contains("register") || s.contains("till") || s.contains("closing") { return "creditcard" }
    if s.contains("table") { return "table.furniture" }
    if s.contains("asset") || s.contains("depreciation") || s.contains("lease") || s.contains("amortization") { return "building.2" }
    if s.contains("capital") || s.contains("share") || s.contains("investment") { return "chart.pie" }
    if s.contains("request") { return "list.clipboard" }
    if s.contains("site") || s.contains("block") || s.contains("department") { return "mappin.and.ellipse" }
    return "square.grid.2x2"
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
                .font(.system(size: size * 0.38, weight: .medium))
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
        HStack(spacing: 12) {
            IagIconWell(systemName: systemName, color: color, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(IagTheme.hairline, lineWidth: 0.5)
            )
    }
}

struct IagKeyValue: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct IagRowDivider: View {
    var inset: CGFloat = 66

    var body: some View {
        Rectangle()
            .fill(IagTheme.hairline)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

struct PageStats: View {
    var stats: [(label: String, value: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.value)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(stat.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if index < stats.count - 1 {
                    Rectangle()
                        .fill(IagTheme.hairline)
                        .frame(width: 0.5, height: 22)
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(IagTheme.hairline, lineWidth: 0.5)
        )
    }
}

struct SectionHeading: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

func prettyLabel(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.contains(" ") || trimmed.contains("&") || trimmed.contains("(") { return trimmed }
    var words: [String] = []
    var current = ""
    for character in trimmed {
        if character == "_" || character == "-" {
            if !current.isEmpty { words.append(current); current = "" }
            continue
        }
        if character.isUppercase, !current.isEmpty, current.last?.isLowercase == true {
            words.append(current)
            current = String(character)
        } else {
            current.append(character)
        }
    }
    if !current.isEmpty { words.append(current) }
    return words.map { word in
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }.joined(separator: " ")
}

func compactMoney(_ amount: Double) -> String {
    let sign = amount < 0 ? "-" : ""
    let magnitude = Swift.abs(amount)
    if magnitude >= 1_000_000_000 { return "\(sign)UGX \(String(format: "%.1f", magnitude / 1_000_000_000))B" }
    if magnitude >= 1_000_000 { return "\(sign)UGX \(String(format: "%.0f", magnitude / 1_000_000))M" }
    if magnitude >= 10_000 { return "\(sign)UGX \(String(format: "%.0f", magnitude / 1_000))K" }
    return formatMoney(amount)
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
                        .foregroundStyle(IagTheme.onLeaf)
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
                        .foregroundStyle(IagTheme.onLeaf)
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
                .padding(.vertical, 8)
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
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 20)
    }

    func iagCard() -> some View {
        self.background(IagTheme.card, in: RoundedRectangle(cornerRadius: IagTheme.radius, style: .continuous))
    }
}
