import SwiftUI
import ErpCore

struct DepartmentView: View {
    @EnvironmentObject var box: StoreBox
    let moduleId: String
    @State private var query = ""

    var body: some View {
        let store = box.store
        let _ = box.tick
        if let module = store.moduleById(moduleId), store.canOpen(moduleId) {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let entities = module.entities.filter { q.isEmpty || $0.lowercased().contains(q) }
            List {
                Section {
                    Text(module.description).foregroundStyle(.secondary)
                }
                Section("\(module.entities.count) features") {
                    ForEach(entities, id: \.self) { entity in
                        NavigationLink {
                            EntityListView(moduleId: moduleId, entity: entity)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entity)
                                    Text("\(store.count(moduleId: moduleId, entity: entity)) records")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(module.label)
            .searchable(text: $query, prompt: "Find a feature")
        } else {
            ContentUnavailableView("Access denied", systemImage: "lock", description: Text("Your role cannot open this department."))
        }
    }
}

struct EntityListView: View {
    @EnvironmentObject var box: StoreBox
    let moduleId: String
    let entity: String
    @State private var query = ""

    var body: some View {
        let store = box.store
        let _ = box.tick
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rows = store.forEntity(moduleId, entity).filter {
            q.isEmpty
                || $0.title.lowercased().contains(q)
                || $0.subtitle.lowercased().contains(q)
                || $0.status.lowercased().contains(q)
        }
        List {
            if moduleId == "reports" {
                Section("Snapshot") {
                    ForEach(reportLines(for: entity), id: \.0) { line in
                        LabeledContent(line.0, value: line.1)
                    }
                }
            }
            if rows.isEmpty {
                Text("No \(entity.lowercased()) yet.").foregroundStyle(.secondary)
            }
            ForEach(rows, id: \.id) { rec in
                NavigationLink {
                    RecordDetailView(recordId: rec.id)
                } label: {
                    VStack(alignment: .leading) {
                        Text(rec.title)
                        Text(rec.subtitle).font(.caption).foregroundStyle(.secondary)
                        Text(rec.status).foregroundStyle(statusColor(rec.status))
                        if let amount = rec.amount { Text(formatMoney(amount)).fontWeight(.semibold) }
                    }
                }
            }
        }
        .navigationTitle(entity)
        .searchable(text: $query, prompt: "Filter records")
        .toolbar {
            if store.canCreate(moduleId, entity) {
                NavigationLink { RecordFormView(moduleId: moduleId, entity: entity) } label: { Image(systemName: "plus") }
            }
        }
    }
}

struct RecordDetailView: View {
    @EnvironmentObject var box: StoreBox
    @Environment(\.dismiss) private var dismiss
    let recordId: String
    @State private var message: String?

    var body: some View {
        let store = box.store
        let _ = box.tick
        if let record = store.records.first(where: { $0.id == recordId }) {
            Form {
                Section {
                    Text(record.entity).foregroundStyle(.secondary)
                    Text(record.subtitle)
                    Text(record.status).foregroundStyle(statusColor(record.status))
                    Text(record.date).foregroundStyle(.secondary)
                    if let amount = record.amount { Text(formatMoney(amount)).fontWeight(.bold) }
                    ForEach(record.fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
                if let message { Text(message).foregroundStyle(.red) }
                if record.status.lowercased() == "draft" {
                    Button("Submit") { message = store.submitRecord(record) ?? "Submitted." }
                }
                if store.canApproveModule(record.moduleId) && store.isOpenStatus(record.status) {
                    Button("Approve") { message = store.approveRecord(record) ?? "Approved." }
                    Button("Reject", role: .destructive) { message = store.rejectRecord(record) ?? "Rejected." }
                }
                if store.canVoid(record.moduleId) {
                    Button("Void", role: .destructive) { message = store.voidRecord(record) ?? "Voided." }
                }
                if store.canDelete(record.moduleId, record.entity) {
                    Button("Delete", role: .destructive) {
                        if let err = store.deleteRecord(record) {
                            message = err
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(record.title)
        } else {
            ContentUnavailableView("Record not found", systemImage: "doc")
        }
    }
}

struct RecordFormView: View {
    @EnvironmentObject var box: StoreBox
    @Environment(\.dismiss) private var dismiss
    let moduleId: String
    let entity: String
    @State private var title = ""
    @State private var subtitle = ""
    @State private var amount = ""
    @State private var error: String?

    var body: some View {
        Form {
            if !box.store.canCreate(moduleId, entity) {
                Text("Your role cannot create this record.")
            } else {
                TextField("Title", text: $title)
                TextField("Subtitle", text: $subtitle)
                TextField("Amount (UGX)", text: $amount)
                    .keyboardType(.decimalPad)
                if let error { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("New \(entity)")
        .toolbar {
            Button("Save") {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    error = "Title is required."
                    return
                }
                box.store.addRecord(ErpRecord(
                    id: newId(),
                    moduleId: moduleId,
                    entity: entity,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    status: "Draft",
                    date: todayIsoDate(),
                    amount: Double(amount.trimmingCharacters(in: .whitespacesAndNewlines))
                ))
                dismiss()
            }
        }
    }
}
