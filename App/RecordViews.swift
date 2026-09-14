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
                            if entity == "Clock In" {
                                ClockInView()
                            } else {
                                EntityListView(moduleId: moduleId, entity: entity)
                            }
                        } label: {
                            DeskRow(
                                title: entity,
                                subtitle: "\(store.count(moduleId: moduleId, entity: entity)) records",
                                systemName: "square.grid.2x2",
                                color: iagColor(module.color)
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .iagCanvas()
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
        if entity == "Clock In" {
            ClockInView()
        } else {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let rows = store.recordsFor(moduleId, entity).filter {
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
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rec.title).font(.body.weight(.semibold))
                                Text(rec.subtitle).font(.caption).foregroundStyle(.secondary)
                                if let amount = rec.amount {
                                    Text(formatMoney(amount)).font(.subheadline.weight(.semibold))
                                }
                            }
                            Spacer(minLength: 8)
                            StatusPill(text: rec.status)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .iagCanvas()
            .navigationTitle(entity)
            .searchable(text: $query, prompt: "Filter records")
            .task(id: "\(moduleId)|\(entity)") {
                await box.store.refreshEntity(moduleId, entity)
            }
            .toolbar {
                if store.canCreate(moduleId, entity) && entity != "My punches" && entity != "Punch Log" {
                    NavigationLink { RecordFormView(moduleId: moduleId, entity: entity) } label: { Image(systemName: "plus") }
                }
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
                    StatusPill(text: record.status)
                    Text(record.date).foregroundStyle(.secondary)
                    if let amount = record.amount { Text(formatMoney(amount)).fontWeight(.bold) }
                    ForEach(record.fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
                if let message { Text(message).foregroundStyle(.red) }
                if record.status.lowercased() == "draft" {
                    Button("Submit") {
                        Task {
                            let result = box.store.remoteSession
                                ? await box.store.submitRecordAsync(record)
                                : box.store.submitRecord(record)
                            await MainActor.run { message = result ?? "Submitted." }
                        }
                    }
                }
                if store.canApproveModule(record.moduleId) && store.isOpenStatus(record.status) {
                    Button("Approve") {
                        Task {
                            let result = box.store.remoteSession
                                ? await box.store.approveRecordAsync(record)
                                : box.store.approveRecord(record)
                            await MainActor.run { message = result ?? "Approved." }
                        }
                    }
                    Button("Reject", role: .destructive) {
                        Task {
                            let result = box.store.remoteSession
                                ? await box.store.rejectRecordAsync(record)
                                : box.store.rejectRecord(record)
                            await MainActor.run { message = result ?? "Rejected." }
                        }
                    }
                }
                if store.canVoid(record.moduleId) {
                    Button("Void", role: .destructive) {
                        Task {
                            let result = box.store.remoteSession
                                ? await box.store.voidRecordAsync(record)
                                : box.store.voidRecord(record)
                            await MainActor.run { message = result ?? "Voided." }
                        }
                    }
                }
                if store.canDelete(record.moduleId, record.entity) {
                    Button("Delete", role: .destructive) {
                        Task {
                            let err = box.store.remoteSession
                                ? await box.store.deleteRecordAsync(record)
                                : box.store.deleteRecord(record)
                            await MainActor.run {
                                if let err { message = err } else { dismiss() }
                            }
                        }
                    }
                }
            }
            .iagCanvas()
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
        .iagCanvas()
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
