import Foundation

struct SavedRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var values: [String: String]
    var updatedAt: Date

    func title(in form: FormDef) -> String {
        for field in form.fields where !field.readOnly {
            let value = values[field.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty {
                return value
            }
        }
        return "Untitled"
    }
}

private struct StoreFile: Codable {
    var records: [String: [SavedRecord]]
}

@MainActor
final class RecordStore: ObservableObject {
    let systemID: String
    @Published private(set) var records: [String: [SavedRecord]] = [:]

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("IAG", isDirectory: true)
        return base.appendingPathComponent("\(systemID).json")
    }

    init(systemID: String) {
        self.systemID = systemID
        load()
    }

    func records(for formID: String) -> [SavedRecord] {
        records[formID] ?? []
    }

    func save(formID: String, record: SavedRecord) {
        var list = records[formID] ?? []
        if let index = list.firstIndex(where: { $0.id == record.id }) {
            list[index] = record
        } else {
            list.insert(record, at: 0)
        }
        records[formID] = list
        persist()
    }

    func delete(formID: String, at offsets: IndexSet) {
        var list = records[formID] ?? []
        list.remove(atOffsets: offsets)
        records[formID] = list
        persist()
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? decoder.decode(StoreFile.self, from: data) else {
            return
        }
        records = file.records
    }

    private func persist() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(StoreFile(records: records)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
