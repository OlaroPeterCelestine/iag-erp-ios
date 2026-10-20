import Foundation

struct CatalogFile: Decodable {
    let systems: [SystemCatalog]
}

struct SystemCatalog: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let folder: String
    let port: Int?
    let summary: String
    let groups: [FormGroup]

    var recordFormCount: Int {
        groups.flatMap(\.forms).filter { !$0.fields.isEmpty }.count
    }

    var subtitle: String {
        switch id {
        case "pos":
            return "Till on this phone"
        case "erp-api":
            return "Sign-in service"
        default:
            let count = recordFormCount
            return count == 1 ? "1 form" : "\(count) forms"
        }
    }

    var allForms: [FormDef] {
        groups.flatMap(\.forms)
    }

    func form(named name: String) -> FormDef? {
        for group in groups {
            if let form = group.forms.first(where: { $0.name == name }) {
                return form
            }
        }
        return nil
    }
}

struct FormGroup: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let forms: [FormDef]
}

struct FormDef: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let note: String
    let fields: [FieldDef]
}

struct FieldDef: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
    let kind: String
    let required: Bool
    let readOnly: Bool
    let choices: [String]
}

enum CatalogLoader {
    static func load() -> Result<[SystemCatalog], Error> {
        guard let url = Bundle.main.url(forResource: "systems", withExtension: "json") else {
            return .failure(CatalogError.missingFile)
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(CatalogFile.self, from: data)
            return .success(file.systems)
        } catch {
            return .failure(error)
        }
    }
}

enum CatalogError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        "systems.json is not in the app bundle."
    }
}
