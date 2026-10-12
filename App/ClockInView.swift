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
        let punches = store.myPunches()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageStats(stats: [
                    ("Status", open == nil ? "Out" : "In"),
                    ("Punches", "\(punches.count)"),
                    ("Site", check?.status ?? "—"),
                    ("GPS", gps.latitude == nil ? "Off" : "\(Int(gps.accuracy.rounded())) m"),
                ])
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

                SectionHeading(title: "Where you are", detail: check?.status)
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

                SectionHeading(title: "Punches", detail: punches.isEmpty ? nil : "\(punches.count)")
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
        .iagBar("Clock In", subtitle: box.store.activeSuiteApp?.label ?? box.store.user?.role ?? appName)
        .onAppear { gps.refresh() }
        .task {
            await box.store.refreshEntity("payroll", "Sites")
            await box.store.refreshEntity("payroll", "Blocks")
            await box.store.refreshEntity("payroll", "Attendance")
        }
    }
}

struct AttendanceCalendarView: View {
    @EnvironmentObject var box: StoreBox
    @State private var anchor = Date()
    @State private var selected = Date()

    var body: some View {
        let store = box.store
        let _ = box.tick
        let punches = store.myPunches()
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let leading = calendar.component(.weekday, from: monthStart) - 1
        let days = (1...dayCount).compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        let selectedKey = isoDay(selected)
        let selectedPunch = punches.first { $0.date == selectedKey }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                        .buttonStyle(.plain)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(monthStart.formatted(.dateTime.month(.wide).year()))
                            .font(.subheadline.weight(.semibold))
                        Text(store.user?.role ?? store.activeSuiteApp?.label ?? appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                        .buttonStyle(.plain)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(0..<leading, id: \.self) { _ in
                        Color.clear.frame(height: 40)
                    }
                    ForEach(days, id: \.timeIntervalSince1970) { day in
                        let mark = dayMark(day, punches: punches)
                        Button { selected = day } label: {
                            VStack(spacing: 4) {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.caption.weight(calendar.isDateInToday(day) ? .bold : .regular))
                                    .foregroundStyle(calendar.isDate(day, inSameDayAs: selected) ? IagTheme.onLeaf : .primary)
                                Circle()
                                    .fill(markColor(mark))
                                    .frame(width: 6, height: 6)
                                    .opacity(mark.isEmpty ? 0 : 1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                calendar.isDate(day, inSameDayAs: selected) ? IagTheme.leaf : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(IagTheme.hairline, lineWidth: 0.5))
                HStack(spacing: 12) {
                    legendDot("Present", IagTheme.leaf)
                    legendDot("Leave", IagTheme.leaf.opacity(0.45))
                    legendDot("Absent", .red.opacity(0.7))
                    legendDot("Off", .secondary.opacity(0.45))
                }
                IagGrouped {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.subheadline.weight(.semibold))
                        Text(dayMark(selected, punches: punches).isEmpty ? "No attendance yet." : dayMark(selected, punches: punches))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let selectedPunch {
                            Text("\(recordField(selectedPunch, "clockIn", "Clock in")) – \(recordField(selectedPunch, "clockOut", "Clock out"))")
                                .font(.caption)
                            if !recordField(selectedPunch, "site", "Site").isEmpty {
                                Text(recordField(selectedPunch, "site", "Site"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar("Calendar", subtitle: store.activeSuiteApp?.label ?? store.user?.role ?? appName)
    }

    private func shiftMonth(_ delta: Int) {
        anchor = Calendar.current.date(byAdding: .month, value: delta, to: anchor) ?? anchor
    }

    private func legendDot(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private func isoDay(_ date: Date) -> String {
    let c = Calendar.current
    return String(format: "%04d-%02d-%02d", c.component(.year, from: date), c.component(.month, from: date), c.component(.day, from: date))
}

private func dayMark(_ date: Date, punches: [ErpRecord]) -> String {
    let key = isoDay(date)
    if let punch = punches.first(where: { $0.date == key }) {
        let status = punch.status.lowercased()
        if status.contains("leave") { return "Leave" }
        return "Present"
    }
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)
    if weekday == 1 || weekday == 7 { return "Off" }
    if calendar.startOfDay(for: date) < calendar.startOfDay(for: Date()) { return "Absent" }
    return ""
}

private func markColor(_ mark: String) -> Color {
    switch mark {
    case "Present": return IagTheme.leaf
    case "Leave": return IagTheme.leaf.opacity(0.45)
    case "Absent": return .red.opacity(0.7)
    case "Off": return .secondary.opacity(0.45)
    default: return .clear
    }
}
