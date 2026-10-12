import Foundation

private struct StoredFormField: Decodable {
    var key: String
    var label: String
    var type: String
    var required: Bool
    var options: [String]
}

private final class FormSpecAnchor {}

private func formSpecData() -> Data? {
    let bundles = [Bundle(for: FormSpecAnchor.self), Bundle.main]
    for bundle in bundles {
        if let url = bundle.url(forResource: "FormSpecs", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        guard let nested = bundle.url(forResource: "ErpIOS_ErpCore", withExtension: "bundle"),
              let resourceBundle = Bundle(url: nested),
              let url = resourceBundle.url(forResource: "FormSpecs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { continue }
        return data
    }
    return nil
}

private let loadedFormSpecs: [String: [FormFieldSpec]] = {
    guard let data = formSpecData(),
          let raw = try? JSONDecoder().decode([String: [StoredFormField]].self, from: data) else {
        return [:]
    }
    var out: [String: [FormFieldSpec]] = [:]
    out.reserveCapacity(raw.count)
    for (key, fields) in raw {
        out[key] = fields.map { FormFieldSpec(key: $0.key, label: $0.label, type: $0.type, required: $0.required, options: $0.options) }
    }
    return out
}()

func formSpecCatalogLookup(_ key: String) -> [FormFieldSpec] {
    loadedFormSpecs[key] ?? []
}
