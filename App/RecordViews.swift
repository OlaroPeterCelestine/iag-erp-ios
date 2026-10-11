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
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(entities.count) features")
                        .font(.title3.weight(.bold))
                    if entities.isEmpty {
                        IagEmptyHint(text: "No features match.", systemName: "square.grid.2x2")
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                                        systemName: module.icon,
                                        color: iagColor(module.color)
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
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
                        Text("Snapshot").font(.title3.weight(.bold))
                        IagGrouped {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(reportLines(for: entity), id: \.0) { line in
                                    LabeledContent(line.0, value: line.1)
                                }
                            }
                            .padding(16)
                        }
                    }
                    Text(entity).font(.title3.weight(.bold))
                    if rows.isEmpty {
                        IagEmptyHint(text: "No \(entity.lowercased()) yet.", systemName: "tray")
                            .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        IagGrouped {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, rec in
                                NavigationLink {
                                    RecordDetailView(recordId: rec.id)
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        IagIconWell(systemName: "doc.text", color: statusColor(rec.status))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(rec.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Text(rec.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 8)
                                        VStack(alignment: .trailing, spacing: 6) {
                                            if let amount = rec.amount {
                                                Text(formatMoney(amount))
                                                    .font(.subheadline.weight(.semibold))
                                                    .monospacedDigit()
                                                    .foregroundStyle(.primary)
                                            }
                                            StatusPill(text: rec.status)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
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
                                    .font(.system(size: 32, weight: .bold))
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
                        .padding(16)
                    }
                    if !record.fields.isEmpty {
                        Text("Details").font(.title3.weight(.bold))
                        IagGrouped {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(record.fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    LabeledContent(key, value: value)
                                }
                            }
                            .padding(16)
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
                    .buttonStyle(.borderedProminent)
                    .tint(IagTheme.leaf)
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
                    .buttonStyle(.borderedProminent)
                    .tint(IagTheme.leaf)
                    Button("Reject", role: .destructive) {
                        Task {
                            let result = box.store.remoteSession
                                ? await box.store.rejectRecordAsync(record)
                                : box.store.rejectRecord(record)
                            await MainActor.run { message = result ?? "Rejected." }
                        }
                    }
                    .buttonStyle(.bordered)
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
                    .buttonStyle(.bordered)
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
                    .buttonStyle(.bordered)
                }
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
        .iagBar("New \(entity)")
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
