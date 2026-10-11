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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IagGrouped {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((open == nil ? IagTheme.muted : IagTheme.success).opacity(0.16))
                                    .frame(width: 36, height: 36)
                                Image(systemName: open == nil ? "moon.zzz" : "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(open == nil ? IagTheme.muted : IagTheme.success)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(open == nil ? "Clocked out" : "On the clock")
                                    .font(.subheadline.weight(.semibold))
                                Text(store.user?.name ?? "Staff")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let open {
                                    Text("Since \(recordField(open, "clockIn", "Clock in"))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Capture GPS, then clock in at a site.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        if let check {
                            StatusPill(text: check.status)
                            Text(check.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            guard let lat = gps.latitude, let lng = gps.longitude else {
                                message = "Capture GPS first, or use the Head Office demo pin."
                                return
                            }
                            message = store.punch(kind: open == nil ? "in" : "out", latitude: lat, longitude: lng, accuracy: gps.accuracy)
                        } label: {
                            Text(open == nil ? "Clock in" : "Clock out")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(IagTheme.leaf)
                        .disabled(!store.canClockIn)
                        if let message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                }

                Text("Location").font(.subheadline.weight(.semibold))
                IagGrouped {
                    if let lat = gps.latitude, let lng = gps.longitude {
                        IagKeyValue(label: "GPS", value: String(format: "%.5f, %.5f", lat, lng))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        IagRowDivider()
                        IagKeyValue(label: "Accuracy", value: "\(Int(gps.accuracy.rounded())) m")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        IagRowDivider()
                    } else {
                        Text("Waiting for GPS…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        IagRowDivider()
                    }
                    Button { gps.refresh() } label: {
                        Label(gps.busy ? "Reading GPS…" : "Refresh GPS", systemImage: "location")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(IagTheme.leaf)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(gps.busy)
                    IagRowDivider()
                    Button { gps.useHq() } label: {
                        Label("Head Office demo pin", systemImage: "mappin")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(IagTheme.leaf)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if let err = gps.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                }

                Text("My punches").font(.subheadline.weight(.semibold))
                let punches = store.myPunches()
                if punches.isEmpty {
                    IagEmptyHint(text: "No punches yet.", systemName: "clock")
                        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    IagGrouped {
                        ForEach(Array(punches.prefix(12).enumerated()), id: \.element.id) { index, rec in
                            NavigationLink {
                                RecordDetailView(recordId: rec.id)
                            } label: {
                                DeskRow(
                                    title: rec.title,
                                    subtitle: "\(recordField(rec, "clockIn", "Clock in"))–\(recordField(rec, "clockOut", "Clock out"))",
                                    systemName: "clock",
                                    color: IagTheme.leaf,
                                    status: rec.status
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            if index < min(punches.count, 12) - 1 { IagRowDivider() }
                        }
                    }
                }
            }
            .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar("Clock In", subtitle: appName)
        .onAppear { gps.refresh() }
        .task {
            await box.store.refreshEntity("payroll", "Sites")
            await box.store.refreshEntity("payroll", "Blocks")
            await box.store.refreshEntity("payroll", "Attendance")
        }
    }
}
