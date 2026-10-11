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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !module.description.isEmpty {
                        Text(module.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if entities.isEmpty {
                        IagEmptyHint(text: "No features match.", systemName: "square.grid.2x2")
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        IagGrouped {
                            ForEach(Array(entities.enumerated()), id: \.element) { index, entity in
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
                                        systemName: entityIcon(entity),
                                        color: iagColor(module.color)
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                if index < entities.count - 1 { IagRowDivider() }
                            }
                        }
                    }
                }
                .iagPage()
            }
            .scrollIndicators(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
            .iagBar(module.label, subtitle: module.group)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if moduleId == "reports" {
                        Text("Snapshot").font(.subheadline.weight(.semibold))
                        IagGrouped {
                            ForEach(Array(reportLines(for: entity).enumerated()), id: \.element.0) { index, line in
                                IagKeyValue(label: line.0, value: line.1)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                if index < reportLines(for: entity).count - 1 { IagRowDivider() }
                            }
                        }
                    }
                    Text(entity).font(.subheadline.weight(.semibold))
                    if rows.isEmpty {
                        IagEmptyHint(text: "No \(entity.lowercased()) yet.", systemName: "tray")
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        IagGrouped {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, rec in
                                NavigationLink {
                                    RecordDetailView(recordId: rec.id)
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        IagIconWell(systemName: entityIcon(entity), color: statusColor(rec.status), size: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(rec.title)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text(rec.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 8)
                                        VStack(alignment: .trailing, spacing: 4) {
                                            if let amount = rec.amount {
                                                Text(formatMoney(amount))
                                                    .font(.caption.weight(.semibold))
                                                    .monospacedDigit()
                                                    .foregroundStyle(.primary)
                                            }
                                            StatusPill(text: rec.status)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                if index < rows.count - 1 { IagRowDivider() }
                            }
                        }
                    }
                }
                .iagPage()
            }
            .scrollIndicators(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
            .iagBar(entity, subtitle: store.moduleById(moduleId)?.label)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    IagGrouped {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(record.entity)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                StatusPill(text: record.status)
                            }
                            if let amount = record.amount {
                                Text(formatMoney(amount))
                                    .font(.title2.weight(.medium))
                                    .monospacedDigit()
                            }
                            if !record.subtitle.isEmpty {
                                Text(record.subtitle)
                                    .font(.body)
                            }
                            Text(record.date)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                    if !record.fields.isEmpty {
                        Text("Details").font(.subheadline.weight(.semibold))
                        let fields = record.fields.sorted { $0.key < $1.key }
                        IagGrouped {
                            ForEach(Array(fields.enumerated()), id: \.element.key) { index, field in
                                IagKeyValue(label: field.key, value: field.value)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                if index < fields.count - 1 { IagRowDivider() }
                            }
                        }
                    }
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    recordActions(store: store, record: record)
                }
                .iagPage()
            }
            .scrollIndicators(.hidden)
            .background(IagTheme.canvas.ignoresSafeArea())
            .iagBar(record.title, subtitle: record.entity)
        } else {
            ContentUnavailableView("Record not found", systemImage: "doc")
        }
    }

    @ViewBuilder
    private func recordActions(store: ErpStore, record: ErpRecord) -> some View {
        let draft = record.status.lowercased() == "draft"
        let canDecide = store.canApproveModule(record.moduleId) && store.isOpenStatus(record.status)
        let canVoid = store.canVoid(record.moduleId)
        let canDelete = store.canDelete(record.moduleId, record.entity)
        if draft || canDecide || canVoid || canDelete {
            VStack(spacing: 8) {
                if draft {
                    recordButton("Submit", prominent: true) {
                        let result = store.remoteSession ? await store.submitRecordAsync(record) : store.submitRecord(record)
                        message = result ?? "Submitted."
                    }
                }
                if canDecide {
                    recordButton("Approve", prominent: true) {
                        let result = store.remoteSession ? await store.approveRecordAsync(record) : store.approveRecord(record)
                        message = result ?? "Approved."
                    }
                    recordButton("Reject", prominent: false) {
                        let result = store.remoteSession ? await store.rejectRecordAsync(record) : store.rejectRecord(record)
                        message = result ?? "Rejected."
                    }
                }
                if canVoid {
                    recordButton("Void", prominent: false) {
                        let result = store.remoteSession ? await store.voidRecordAsync(record) : store.voidRecord(record)
                        message = result ?? "Voided."
                    }
                }
                if canDelete {
                    recordButton("Delete", prominent: false) {
                        let err = store.remoteSession ? await store.deleteRecordAsync(record) : store.deleteRecord(record)
                        if let err { message = err } else { dismiss() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recordButton(_ title: String, prominent: Bool, action: @escaping () async -> Void) -> some View {
        let label = Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 40)
        if prominent {
            Button { Task { await action() } } label: { label }
                .buttonStyle(.borderedProminent)
                .tint(IagTheme.leaf)
        } else {
            Button { Task { await action() } } label: { label }
                .buttonStyle(.bordered)
                .tint(.red)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !box.store.canCreate(moduleId, entity) {
                    IagEmptyHint(text: "Your role cannot create this record.", systemName: "lock")
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    IagGrouped {
                        formField("Title", text: $title)
                        IagRowDivider()
                        formField("Subtitle", text: $subtitle)
                        IagRowDivider()
                        formField("Amount (UGX)", text: $amount, numeric: true)
                    }
                    if let error {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    Button(action: save) {
                        Text("Save draft")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IagTheme.leaf)
                }
            }
            .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar("New \(entity)")
    }

    private func formField(_ label: String, text: Binding<String>, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: text)
                .font(.subheadline)
                .keyboardType(numeric ? .decimalPad : .default)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func save() {
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
