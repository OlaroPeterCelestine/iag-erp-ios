import SwiftUI

struct TillProduct: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var price: String
}

struct TillLine: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var price: String
    var quantity: Int
}

struct TillSale: Codable, Identifiable, Hashable {
    var id: UUID
    var at: Date
    var method: String
    var lines: [TillLine]
    var total: String
}

private struct TillFile: Codable {
    var pin: String = ""
    var products: [TillProduct] = []
    var sales: [TillSale] = []
}

@MainActor
final class TillStore: ObservableObject {
    @Published var pin = ""
    @Published var unlocked = false
    @Published var products: [TillProduct] = []
    @Published var sales: [TillSale] = []
    @Published var cart: [TillLine] = []

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IAG", isDirectory: true)
        return base.appendingPathComponent("pos-till.json")
    }

    init() {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(TillFile.self, from: data) else {
            return
        }
        pin = file.pin
        products = file.products
        sales = file.sales
    }

    var hasPIN: Bool { pin.count >= 4 }

    func setPIN(_ value: String) {
        pin = value
        unlocked = true
        persist()
    }

    func unlock(_ value: String) -> Bool {
        guard value == pin else { return false }
        unlocked = true
        return true
    }

    func lock() {
        unlocked = false
        cart = []
    }

    func add(_ product: TillProduct) {
        if let index = cart.firstIndex(where: { $0.name == product.name && $0.price == product.price }) {
            cart[index].quantity += 1
        } else {
            cart.append(TillLine(id: UUID(), name: product.name, price: product.price, quantity: 1))
        }
    }

    func recordSale(method: String) {
        let total = cart.reduce(0.0) { partial, line in
            partial + (Double(line.price) ?? 0) * Double(line.quantity)
        }
        sales.insert(
            TillSale(
                id: UUID(),
                at: Date(),
                method: method,
                lines: cart,
                total: String(format: "%.2f", total)
            ),
            at: 0
        )
        cart = []
        persist()
    }

    func saveProduct(name: String, price: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        products.append(TillProduct(id: UUID(), name: trimmed, price: price))
        persist()
    }

    func deleteProducts(at offsets: IndexSet) {
        products.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = TillFile(pin: pin, products: products, sales: sales)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

struct TillView: View {
    @StateObject private var till = TillStore()

    var body: some View {
        Group {
            if !till.hasPIN {
                PINSetupView(till: till)
            } else if !till.unlocked {
                PINEntryView(till: till)
            } else {
                TillTerminal(till: till)
            }
        }
    }
}

private struct PINSetupView: View {
    @ObservedObject var till: TillStore
    @State private var first = ""
    @State private var second = ""
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                Text("Choose a 4-digit PIN for this phone. It stays on the device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                SecureField("PIN", text: $first)
                    .keyboardType(.numberPad)
                SecureField("Confirm PIN", text: $second)
                    .keyboardType(.numberPad)
                if let problem {
                    Text(problem).foregroundStyle(.red)
                }
            }
            Button("Save PIN") {
                let digits = first.filter(\.isNumber)
                guard digits.count == 4, digits == second.filter(\.isNumber) else {
                    problem = "Enter the same 4 digits twice."
                    return
                }
                till.setPIN(digits)
            }
        }
    }
}

private struct PINEntryView: View {
    @ObservedObject var till: TillStore
    @State private var entry = ""
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                SecureField("PIN", text: $entry)
                    .keyboardType(.numberPad)
                if let problem {
                    Text(problem).foregroundStyle(.red)
                }
            }
            Button("Unlock") {
                if !till.unlock(entry.filter(\.isNumber)) {
                    problem = "PIN does not match."
                }
            }
        }
    }
}

private struct TillTerminal: View {
    @ObservedObject var till: TillStore
    @State private var tab = 0
    @State private var showCart = false
    @State private var newName = ""
    @State private var newPrice = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Till", selection: $tab) {
                Text("Sell").tag(0)
                Text("Catalog").tag(1)
                Text("Sales").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            switch tab {
            case 1:
                catalog
            case 2:
                sales
            default:
                sell
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Lock") { till.lock() }
            }
        }
        .sheet(isPresented: $showCart) {
            NavigationStack {
                CartSheet(till: till)
            }
        }
    }

    private var sell: some View {
        ScrollView {
            if till.products.isEmpty {
                ContentUnavailableView("No products", systemImage: "square.grid.2x2", description: Text("Add products on the Catalog tab."))
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(till.products) { product in
                        Button {
                            till.add(product)
                            showCart = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(product.price)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var catalog: some View {
        List {
            Section("Add product") {
                TextField("Name", text: $newName)
                TextField("Price", text: $newPrice)
                    .keyboardType(.decimalPad)
                Button("Add") {
                    till.saveProduct(name: newName, price: newPrice)
                    newName = ""
                    newPrice = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("On the grid") {
                ForEach(till.products) { product in
                    HStack {
                        Text(product.name)
                        Spacer()
                        Text(product.price).foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: till.deleteProducts)
            }
        }
    }

    private var sales: some View {
        List(till.sales) { sale in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(sale.method) · \(sale.total)")
                Text(sale.at.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if till.sales.isEmpty {
                ContentUnavailableView("No sales", systemImage: "receipt", description: Text("A recorded sale appears here."))
            }
        }
    }
}

private struct CartSheet: View {
    @ObservedObject var till: TillStore
    @Environment(\.dismiss) private var dismiss

    private var total: Double {
        till.cart.reduce(0) { partial, line in
            partial + (Double(line.price) ?? 0) * Double(line.quantity)
        }
    }

    var body: some View {
        List {
            if till.cart.isEmpty {
                Text("Cart is empty.")
                    .foregroundStyle(.secondary)
            }
            ForEach(till.cart) { line in
                HStack {
                    VStack(alignment: .leading) {
                        Text(line.name)
                        Text("\(line.quantity) × \(line.price)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.2f", (Double(line.price) ?? 0) * Double(line.quantity)))
                }
            }
            Section {
                Text("Total \(String(format: "%.2f", total))")
                    .font(.headline)
                Text("Saved on this phone. This does not charge a card or mobile wallet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Cart")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                ForEach(["Cash", "Card", "Mobile"], id: \.self) { method in
                    Button(method) {
                        till.recordSale(method: method)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(till.cart.isEmpty)
                }
            }
            .padding()
            .background(.bar)
        }
    }
}
