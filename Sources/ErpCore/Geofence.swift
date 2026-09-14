import Foundation

public struct GeoPoint: Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct GeofenceZone: Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: String
    public var siteName: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMeters: Double
    public var status: String
}

public struct GeofenceCheck: Equatable, Sendable {
    public var ok: Bool
    public var status: String
    public var distanceMeters: Int
    public var zone: GeofenceZone?
    public var note: String
}

public let hqLatitude = 0.347596
public let hqLongitude = 32.582520
public let acpLatitude = -0.341111
public let acpLongitude = 31.736111

private let earthRadiusM = 6_371_000.0

public func parseCoord(_ value: String?) -> Double? {
    let raw = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty, let n = Double(raw), n.isFinite else { return nil }
    return n
}

public func recordField(_ record: ErpRecord, _ keys: String...) -> String {
    for key in keys {
        if let value = record.fields[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return ""
}

public func haversineMeters(_ a: GeoPoint, _ b: GeoPoint) -> Double {
    func rad(_ deg: Double) -> Double { deg * .pi / 180 }
    let dLat = rad(b.latitude - a.latitude)
    let dLon = rad(b.longitude - a.longitude)
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(rad(a.latitude)) * cos(rad(b.latitude)) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * earthRadiusM * asin(min(1, sqrt(h)))
}

public func zoneFromRecord(_ record: ErpRecord, kind: String) -> GeofenceZone? {
    let lat = parseCoord(recordField(record, "latitude", "Latitude"))
    let lng = parseCoord(recordField(record, "longitude", "Longitude"))
    guard let lat, let lng else { return nil }
    let radius = parseCoord(recordField(record, "radiusMeters", "Radius (m)", "Radius")) ?? 100
    return GeofenceZone(
        id: record.id,
        name: record.title,
        kind: kind,
        siteName: kind == "block" ? (record.subtitle.isEmpty ? record.title : record.subtitle) : record.title,
        latitude: lat,
        longitude: lng,
        radiusMeters: max(10, radius),
        status: record.status
    )
}

public func verifyAgainstZones(_ point: GeoPoint, _ zones: [GeofenceZone], accuracyMeters: Double = 0) -> GeofenceCheck {
    let active = zones.filter { !["inactive", "disabled", "archived", "closed"].contains($0.status.lowercased()) }
    guard let first = active.first else {
        return GeofenceCheck(ok: false, status: "Outside", distanceMeters: .max, zone: nil, note: "No active sites or blocks with coordinates are configured.")
    }
    var best = (zone: first, distance: haversineMeters(point, GeoPoint(latitude: first.latitude, longitude: first.longitude)))
    for zone in active.dropFirst() {
        let distance = haversineMeters(point, GeoPoint(latitude: zone.latitude, longitude: zone.longitude))
        if distance < best.distance { best = (zone, distance) }
    }
    let distanceMeters = Int(best.distance.rounded())
    let effective = max(0, Double(distanceMeters) - min(accuracyMeters, 50))
    if effective <= best.zone.radiusMeters {
        return GeofenceCheck(ok: true, status: "Verified", distanceMeters: distanceMeters, zone: best.zone, note: "Inside \(best.zone.name) geofence (\(distanceMeters) m of \(Int(best.zone.radiusMeters)) m radius).")
    }
    if effective <= best.zone.radiusMeters * 1.5 {
        return GeofenceCheck(ok: false, status: "Flagged", distanceMeters: distanceMeters, zone: best.zone, note: "Near \(best.zone.name) but outside the \(Int(best.zone.radiusMeters)) m radius (\(distanceMeters) m away).")
    }
    return GeofenceCheck(ok: false, status: "Outside", distanceMeters: distanceMeters, zone: best.zone, note: "Outside all geofences. Nearest: \(best.zone.name) at \(distanceMeters) m.")
}

public func nowClock() -> String {
    let c = Calendar.current
    let d = Date()
    return String(format: "%02d:%02d", c.component(.hour, from: d), c.component(.minute, from: d))
}

public func hoursBetween(_ clockIn: String, _ clockOut: String) -> String {
    func minutes(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }
    let mins = max(0, minutes(clockOut) - minutes(clockIn))
    return String(format: "%.2f", Double(mins) / 60)
}

public let webErpDepartmentIds: [String] = [
    "banking", "receipts-payments", "expense-claims", "general-requests", "oral-payment-requests",
    "sales", "purchases", "inventory", "projects", "contract-manager", "fleet", "security", "crm",
    "logistics", "distribution", "rnd", "lab", "qa", "production", "benchmark", "pos", "payroll",
    "investments", "assets", "capital", "accounts", "folders", "documents", "reports",
]
