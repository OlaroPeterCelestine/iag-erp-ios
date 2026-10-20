import SwiftUI

struct SystemView: View {
    let system: SystemCatalog
    @StateObject private var store: RecordStore
    @State private var query = ""

    init(system: SystemCatalog) {
        self.system = system
        _store = StateObject(wrappedValue: RecordStore(systemID: system.id))
    }

    private var groups: [FormGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return system.groups }
        return system.groups.compactMap { group in
            let forms = group.forms.filter { form in
                form.name.localizedCaseInsensitiveContains(trimmed)
                    || form.note.localizedCaseInsensitiveContains(trimmed)
                    || form.fields.contains { $0.label.localizedCaseInsensitiveContains(trimmed) }
            }
            guard !forms.isEmpty || group.name.localizedCaseInsensitiveContains(trimmed) else { return nil }
            return FormGroup(id: group.id, name: group.name, summary: group.summary, forms: forms.isEmpty ? group.forms : forms)
        }
    }

    var body: some View {
        Group {
            if system.id == "pos" {
                TillView()
            } else if system.groups.isEmpty {
                ServiceInfoView(system: system)
            } else {
                formList
            }
        }
        .navigationTitle(system.name)
        .navigationBarTitleDisplayMode(.large)
        .environmentObject(store)
    }

    private var formList: some View {
        List {
            if !system.summary.isEmpty {
                Section {
                    Text(system.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(groups) { group in
                Section {
                    if !group.summary.isEmpty {
                        Text(group.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(group.forms) { form in
                        NavigationLink {
                            FormScreen(form: form)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(form.name)
                                Text(form.fields.isEmpty ? "View" : "\(form.fields.count) fields")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(group.name)
                }
            }
        }
        .searchable(text: $query, prompt: "Search \(system.name)")
    }
}

private struct ServiceInfoView: View {
    let system: SystemCatalog

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(system.summary)
                    .font(.body)
                if let port = system.port {
                    Text("Port \(port)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct FormScreen: View {
    let form: FormDef
    @EnvironmentObject private var store: RecordStore

    var body: some View {
        Group {
            if form.fields.isEmpty {
                ScrollView {
                    Text(form.note.isEmpty ? "This screen does not save a new row." : form.note)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                recordList
            }
        }
        .navigationTitle(form.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recordList: some View {
        let rows = store.records(for: form.id)
        return List {
            if !form.note.isEmpty {
                Section {
                    Text(form.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                if rows.isEmpty {
                    Text("No records yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(rows) { record in
                    NavigationLink {
                        RecordEditor(form: form, existing: record)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title(in: form))
                            Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    store.delete(formID: form.id, at: offsets)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    RecordEditor(form: form, existing: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
