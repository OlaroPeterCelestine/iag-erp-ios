import Foundation

/// Maps on-device desk labels to Go `/api/records/:module/:entity` keys.
/// Slug rules match `entityKey()` in IAG Frontend `src/lib/manager-entities.ts`.
public func apiEntityKey(_ label: String) -> String {
    let lower = label.lowercased()
    if lower.contains("warehouse") && lower.contains("location") { return "inventory-locations" }
    if lower.contains("pos") && lower.contains("location") { return "pos-locations" }
    if lower == "new project" || lower == "new-project" { return "projects" }
    if lower.contains("material request") { return "requisitions" }
    if lower == "machines" || lower == "machine" { return "work-centers" }
    if lower.contains("payment request") && !lower.contains("oral") { return "payment-requests" }
    if lower == "clock in" || lower == "my punches" { return "attendance" }
    return lower
        .replacingOccurrences(of: "&", with: "and")
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

public func apiStorageTarget(moduleId: String, entity: String) -> (module: String, entity: String) {
    let key = apiEntityKey(entity)
    switch moduleId {
    case "receipts-payments":
        return ("banking", key)
    case "clock-in":
        return ("payroll", key)
    case "folders":
        return ("documents", key)
    case "general-requests", "oral-payment-requests":
        return ("requests", key)
    case "contract-manager":
        return ("projects", key)
    default:
        return (moduleId, key)
    }
}

public func recordFromApi(_ row: [String: Any], moduleId: String, entity: String) -> ErpRecord {
    let strings = stringifyApiRow(row)
    let title = firstFilled(strings, ["name", "reference", "title", "code", "id"]) ?? newId()
    let subtitle = firstFilled(strings, ["description", "party", "customer", "subtitle", "employee", "account", "site"]) ?? ""
    let status = firstFilled(strings, ["status"]) ?? "Draft"
    let date = firstFilled(strings, ["date", "createdAt", "created"]) ?? ""
    var amount: Double?
    if let raw = firstFilled(strings, ["amount", "balance", "total"]) {
        amount = Double(raw.replacingOccurrences(of: ",", with: ""))
    }
    var fields = strings
    for skip in ["id", "name", "reference", "title", "status", "date", "description", "amount"] {
        fields.removeValue(forKey: skip)
    }
    return ErpRecord(
        id: strings["id"] ?? newId(),
        moduleId: moduleId,
        entity: entity,
        title: title,
        subtitle: subtitle,
        status: status,
        date: date,
        amount: amount,
        fields: fields
    )
}

public func apiPayload(from record: ErpRecord) -> [String: String] {
    var row = record.fields
    row["id"] = record.id
    row["name"] = recTitle(record)
    row["status"] = record.status
    if !record.date.isEmpty { row["date"] = record.date }
    if !record.subtitle.isEmpty { row["description"] = record.subtitle }
    if let amount = record.amount { row["amount"] = String(amount) }
    return row
}

private func recTitle(_ record: ErpRecord) -> String { record.title }

private func stringifyApiRow(_ row: [String: Any]) -> [String: String] {
    var out: [String: String] = [:]
    for (key, value) in row {
        if value is NSNull { continue }
        if let nested = value as? [String: Any] {
            out[key] = nested["name"] as? String ?? nested["id"] as? String ?? "\(nested.count)"
            continue
        }
        if let list = value as? [Any] {
            out[key] = list.map { "\($0)" }.joined(separator: ", ")
            continue
        }
        if let number = value as? NSNumber {
            out[key] = number.stringValue
            continue
        }
        let text = "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { out[key] = text }
    }
    return out
}

private func firstFilled(_ row: [String: String], _ keys: [String]) -> String? {
    for key in keys {
        if let value = row[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return value
        }
    }
    return nil
}
