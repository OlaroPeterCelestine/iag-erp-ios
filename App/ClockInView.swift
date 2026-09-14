import CoreLocation
import SwiftUI
import ErpCore

final class LocationFix: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var accuracy: Double = 0
    @Published var error: String?
    @Published var busy = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func refresh() {
        error = nil
        busy = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            busy = false
            error = "Location is off. Use the Head Office demo pin, or enable Location in Settings."
        default:
            manager.requestLocation()
        }
    }

    func useHq() {
        latitude = hqLatitude
        longitude = hqLongitude
        accuracy = 12
        error = nil
        busy = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            busy = false
            error = "Location is off. Use the Head Office demo pin."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        accuracy = loc.horizontalAccuracy
        busy = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        busy = false
        self.error = error.localizedDescription
    }
}

struct ClockInView: View {
    @EnvironmentObject var box: StoreBox
    @StateObject private var gps = LocationFix()
    @State private var message: String?

    var body: some View {
        let store = box.store
        let _ = box.tick
        let open = store.openAttendanceToday()
        let check: GeofenceCheck? = {
            guard let lat = gps.latitude, let lng = gps.longitude else { return nil }
            return verifyAgainstZones(GeoPoint(latitude: lat, longitude: lng), store.geofenceZones(), accuracyMeters: gps.accuracy)
        }()
        List {
            Section("You") {
                Text(store.user?.name ?? "Staff")
                Text(store.user?.role ?? "").foregroundStyle(.secondary)
                if let open {
                    Text("Checked in at \(recordField(open, "clockIn", "Clock in")) · \(open.subtitle)")
                } else {
                    Text("No open check-in today.").foregroundStyle(.secondary)
                }
            }
            Section("Location") {
                if let lat = gps.latitude, let lng = gps.longitude {
                    LabeledContent("GPS", value: String(format: "%.5f, %.5f", lat, lng))
                    LabeledContent("Accuracy", value: "\(Int(gps.accuracy.rounded())) m")
                } else {
                    Text("Waiting for GPS…").foregroundStyle(.secondary)
                }
                Button(gps.busy ? "Reading GPS…" : "Refresh GPS") { gps.refresh() }
                    .disabled(gps.busy)
                Button("Use IAG Head Office (demo)") { gps.useHq() }
                if let check {
                    Text(check.status).foregroundStyle(statusColor(check.status))
                    Text(check.note).font(.caption).foregroundStyle(.secondary)
                }
                if let err = gps.error {
                    Text(err).foregroundStyle(.red)
                }
                if let message {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            Section("Punch") {
                Button(open == nil ? "Clock in" : "Clock out") {
                    guard let lat = gps.latitude, let lng = gps.longitude else {
                        message = "Capture GPS first, or use the Head Office demo pin."
                        return
                    }
                    message = store.punch(kind: open == nil ? "in" : "out", latitude: lat, longitude: lng, accuracy: gps.accuracy)
                }
                .disabled(!store.canClockIn)
            }
            Section("My punches") {
                let punches = store.myPunches()
                if punches.isEmpty {
                    Text("No punches yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(punches.prefix(12), id: \.id) { rec in
                        NavigationLink {
                            RecordDetailView(recordId: rec.id)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(rec.title)
                                Text("\(rec.status) · \(recordField(rec, "clockIn", "Clock in"))–\(recordField(rec, "clockOut", "Clock out"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Clock In")
        .onAppear { gps.refresh() }
    }
}
