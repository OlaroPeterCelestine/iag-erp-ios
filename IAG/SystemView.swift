import SwiftUI

struct GroupBrowser: View {
    let title: String
    let groups: [FormGroup]
    var showsHeading = true
    @State private var query = ""

    private var visible: [FormGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return groups }
        return groups.compactMap { group in
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
            if visible.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(visible) { group in
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
            }
        }
        .modifier(BrowserHeading(title: showsHeading ? title : nil))
        .searchable(text: $query, prompt: "Search \(title)")
    }
}

private struct BrowserHeading: ViewModifier {
    let title: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let title {
            content.navigationTitle(title)
        } else {
            content
        }
    }
}

struct FormScreen: View {
    let form: FormDef
    @EnvironmentObject private var store: RecordStore
    @EnvironmentObject private var session: SessionStore

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
                    guard session.access.canDelete else { return }
                    store.delete(formID: form.id, at: offsets)
                }
                .deleteDisabled(!session.access.canDelete)
            }
        }
        .toolbar {
            if session.access.canCreate {
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
}
