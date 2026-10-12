import Foundation

public struct PlacePin: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var status: String
    public var latitude: Double
    public var longitude: Double

    public init(id: String, title: String, subtitle: String, status: String, latitude: Double, longitude: Double) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct NamedPlace: Equatable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
}

/// Places used when a vehicle or delivery only names a stop.
public let namedPlaces: [NamedPlace] = [
    NamedPlace(name: "industrial area", latitude: 0.3135, longitude: 32.5965),
    NamedPlace(name: "kisementi", latitude: 0.3372, longitude: 32.5868),
    NamedPlace(name: "namanve", latitude: 0.3853, longitude: 32.6847),
    NamedPlace(name: "entebbe", latitude: 0.0512, longitude: 32.4637),
    NamedPlace(name: "kololo", latitude: 0.3306, longitude: 32.5894),
    NamedPlace(name: "lugogo", latitude: 0.3328, longitude: 32.6045),
    NamedPlace(name: "ntinda", latitude: 0.3532, longitude: 32.6134),
    NamedPlace(name: "masaka", latitude: acpLatitude, longitude: acpLongitude),
    NamedPlace(name: "kampala", latitude: hqLatitude, longitude: hqLongitude),
]

public func coordinate(for record: ErpRecord) -> GeoPoint? {
    if let lat = parseCoord(recordField(record, "latitude", "Latitude", "lat")),
       let lng = parseCoord(recordField(record, "longitude", "Longitude", "lng", "lon", "long")) {
        return GeoPoint(latitude: lat, longitude: lng)
    }
    let blob = ([record.title, record.subtitle] + record.fields.values).joined(separator: " ").lowercased()
    let places = namedPlaces.sorted { $0.name.count > $1.name.count }
    for place in places where blob.contains(place.name) {
        return GeoPoint(latitude: place.latitude, longitude: place.longitude)
    }
    return nil
}

public func fleetMapPins(_ records: [ErpRecord]) -> [PlacePin] {
    spreadPins(records.filter { $0.moduleId == "fleet" && $0.entity == "Vehicles" }.compactMap(mapPin))
}

public func distributionMapPins(_ records: [ErpRecord]) -> [PlacePin] {
    spreadPins(records.filter { record in
        record.moduleId == "distribution" && (record.entity == "Delivery Runs" || record.entity == "Distribution Orders")
    }.compactMap(mapPin))
}

private func mapPin(_ record: ErpRecord) -> PlacePin? {
    guard let point = coordinate(for: record) else { return nil }
    let detail = record.subtitle.isEmpty ? record.status : "\(record.subtitle) · \(record.status)"
    return PlacePin(
        id: record.id,
        title: record.title,
        subtitle: detail,
        status: record.status,
        latitude: point.latitude,
        longitude: point.longitude
    )
}

private func spreadPins(_ pins: [PlacePin]) -> [PlacePin] {
    var seen: [String: Int] = [:]
    return pins.map { pin in
        let key = String(format: "%.4f,%.4f", pin.latitude, pin.longitude)
        let index = seen[key, default: 0]
        seen[key] = index + 1
        guard index > 0 else { return pin }
        let angle = Double(index) * 0.9
        var copy = pin
        copy.latitude += 0.004 * cos(angle)
        copy.longitude += 0.004 * sin(angle)
        return copy
    }
}
