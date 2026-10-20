import SwiftUI
import UniformTypeIdentifiers

struct RecordEditor: View {
    let form: FormDef
    let existing: SavedRecord?

    @EnvironmentObject private var store: RecordStore
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String]
    @State private var problem: String?
    @State private var importerField: String?

    init(form: FormDef, existing: SavedRecord?) {
        self.form = form
        self.existing = existing
        _values = State(initialValue: existing?.values ?? [:])
    }

    var body: some View {
        Form {
            if let problem {
                Section {
                    Text(problem)
                        .foregroundStyle(.red)
                }
            }
            if !form.note.isEmpty, existing == nil {
                Section {
                    Text(form.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(form.fields) { field in
                    fieldRow(field)
                }
            }
        }
        .navigationTitle(existing == nil ? "New" : "Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .fileImporter(
            isPresented: Binding(
                get: { importerField != nil },
                set: { if !$0 { importerField = nil } }
            ),
            allowedContentTypes: [.item]
        ) { result in
            guard let fieldID = importerField, case .success(let url) = result else { return }
            let name = url.lastPathComponent
            let current = values[fieldID] ?? ""
            values[fieldID] = current.isEmpty ? name : current + "\n" + name
        }
    }

    @ViewBuilder
    private func fieldRow(_ field: FieldDef) -> some View {
        if field.readOnly {
            VStack(alignment: .leading, spacing: 4) {
                Text(field.label)
                    .font(.subheadline)
                Text(display(field).isEmpty ? "Filled by the system" : display(field))
                    .foregroundStyle(.secondary)
            }
        } else {
            switch field.kind {
            case "textarea":
                TextField(label(field), text: binding(field.id), axis: .vertical)
                    .lineLimit(3...8)
            case "select":
                Picker(label(field), selection: binding(field.id)) {
                    Text("Select").tag("")
                    ForEach(field.choices, id: \.self) { choice in
                        Text(choice).tag(choice)
                    }
                }
            case "date":
                dateRow(field)
            case "attachments":
                VStack(alignment: .leading, spacing: 6) {
                    Text(label(field))
                    if !display(field).isEmpty {
                        Text(display(field))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Attach file") { importerField = field.id }
                }
            default:
                TextField(label(field), text: binding(field.id))
                    .textInputAutocapitalization(field.kind == "email" ? .never : .sentences)
                    .keyboardType(field.kind == "number" ? .decimalPad : field.kind == "email" ? .emailAddress : .default)
                    .textContentType(field.kind == "email" ? .emailAddress : nil)
            }
        }
    }

    private func dateRow(_ field: FieldDef) -> some View {
        let current = display(field)
        return VStack(alignment: .leading, spacing: 6) {
            if current.isEmpty {
                Button("Set \(field.label)") {
                    values[field.id] = Self.day.string(from: Date())
                }
            } else {
                DatePicker(
                    label(field),
                    selection: Binding(
                        get: { Self.day.date(from: current) ?? Date() },
                        set: { values[field.id] = Self.day.string(from: $0) }
                    ),
                    displayedComponents: .date
                )
                Button("Clear \(field.label)", role: .destructive) {
                    values[field.id] = ""
                }
                .font(.footnote)
            }
        }
    }

    private func label(_ field: FieldDef) -> String {
        field.required ? "\(field.label) *" : field.label
    }

    private func display(_ field: FieldDef) -> String {
        values[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func binding(_ id: String) -> Binding<String> {
        Binding(
            get: { values[id] ?? "" },
            set: { values[id] = $0 }
        )
    }

    private func save() {
        let missing = form.fields.filter { field in
            field.required && !field.readOnly && display(field).isEmpty
        }
        if let first = missing.first {
            problem = "\(first.label) is required."
            return
        }
        var record = existing ?? SavedRecord(id: UUID(), values: [:], updatedAt: Date())
        record.values = values
        record.updatedAt = Date()
        store.save(formID: form.id, record: record)
        dismiss()
    }

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
