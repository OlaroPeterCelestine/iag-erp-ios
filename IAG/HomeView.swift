import SwiftUI

struct HomeView: View {
    @State private var systems: [SystemCatalog] = []
    @State private var loadError: String?
    @State private var query = ""

    private var filtered: [SystemCatalog] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return systems }
        return systems.filter { system in
            system.name.localizedCaseInsensitiveContains(trimmed)
                || system.summary.localizedCaseInsensitiveContains(trimmed)
                || system.groups.contains { group in
                    group.name.localizedCaseInsensitiveContains(trimmed)
                        || group.forms.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
                }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let loadError {
                    ContentUnavailableView("Catalog unavailable", systemImage: "exclamationmark.triangle", description: Text(loadError))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12)], spacing: 12) {
                            ForEach(filtered) { system in
                                NavigationLink(value: system) {
                                    SystemCard(system: system)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("IAG")
            .navigationDestination(for: SystemCatalog.self) { system in
                SystemView(system: system)
            }
            .searchable(text: $query, prompt: "Search systems and forms")
        }
        .task {
            switch CatalogLoader.load() {
            case .success(let loaded):
                systems = loaded
            case .failure(let error):
                loadError = error.localizedDescription
            }
        }
    }
}

private struct SystemCard: View {
    let system: SystemCatalog

    var body: some View {
        let tint = SystemTheme.tint(for: system.id)
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: SystemTheme.symbol(for: system.id))
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(system.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(system.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        }
    }
}
