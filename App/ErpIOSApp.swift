import SwiftUI
import ErpCore

@main
struct ErpIOSApp: App {
    @StateObject private var box = StoreBox()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(box)
        }
    }
}

final class StoreBox: ObservableObject {
    let store: ErpStore
    @Published var tick: Int = 0

    init() {
        let store = ErpStore(persistence: UserDefaultsStore())
        store.load()
        self.store = store
        store.addListener { [weak self] in
            DispatchQueue.main.async { self?.tick += 1 }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var box: StoreBox

    var body: some View {
        let _ = box.tick
        Group {
            if box.store.isSignedIn {
                ShellView()
            } else {
                LoginView()
            }
        }
        .preferredColorScheme(box.store.themeMode == "dark" ? .dark : box.store.themeMode == "light" ? .light : nil)
    }
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
        return Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255)
    }
    if ["overdue", "reject", "void", "cancel", "outside"].contains(where: { s.contains($0) }) {
        return Color(red: 185 / 255, green: 28 / 255, blue: 28 / 255)
    }
    if ["pending", "open", "draft", "held", "flagged", "submitted"].contains(where: { s.contains($0) }) {
        return Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    }
    return .secondary
}
