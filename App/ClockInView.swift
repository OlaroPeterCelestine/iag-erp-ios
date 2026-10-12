import Combine
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
        #if os(iOS)
        let allowed = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
        #else
        let allowed = manager.authorizationStatus == .authorizedAlways
        #endif
        if allowed {
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
    var body: some View {
        AttendanceCalendarView()
    }
}

struct AttendanceCalendarView: View {
    @EnvironmentObject var box: StoreBox
    @StateObject private var gps = LocationFix()
    @State private var anchor = Date()
    @State private var message: String?

    var body: some View {
        let store = box.store
        let _ = box.tick
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)) ?? anchor
        let year = calendar.component(.year, from: monthStart)
        let month = calendar.component(.month, from: monthStart)
        let monthKey = String(format: "%04d-%02d", year, month)
        let holidays = store.publicHolidays(year: year).filter { $0.date.hasPrefix(monthKey) }
        let holidayDates = Set(holidays.map(\.date))
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let days = (1...dayCount).compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        let name = store.user?.name ?? ""
        let punches = store.myPunches().filter { $0.date.hasPrefix(monthKey) }
        let present = punches.filter { !$0.status.lowercased().contains("leave") }
        let presentDates = Set(present.map(\.date))
        let myLeave = store.forEntity("payroll", "Leave Requests").filter { rec in
            guard !name.isEmpty else { return false }
            let mine = rec.subtitle.localizedCaseInsensitiveContains(name)
                || rec.title.localizedCaseInsensitiveContains(name)
                || recordField(rec, "employee", "Employee").localizedCaseInsensitiveContains(name)
            return mine && (rec.date.hasPrefix(monthKey) || rec.date.isEmpty)
        }
        let leaveDates = Set(myLeave.map(\.date)).subtracting([""])
        let counts = monthCounts(days: days, present: presentDates, leave: leaveDates, holidays: holidayDates)
        let fullDays = present.filter { (Double(recordField($0, "hours", "Hours")) ?? 0) >= 4 || recordField($0, "hours", "Hours").isEmpty }.count
        let halfDays = max(0, present.count - fullDays)
        let missedOut = present.filter { recordField($0, "clockOut", "Clock out").isEmpty && $0.date < isoDay(Date()) }.count
        let todayPunch = store.myPunches().first { $0.date == isoDay(Date()) }
        let open = store.openAttendanceToday()
        let inTime = todayPunch.map { recordField($0, "clockIn", "Clock in") } ?? ""
        let outTime = todayPunch.map { recordField($0, "clockOut", "Clock out") } ?? ""
        let spent = spentLabel(todayPunch.map { recordField($0, "hours", "Hours") } ?? "", inTime: inTime, outTime: outTime)
        let queue = pendingLeave(store)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                        .buttonStyle(.plain)
                    Spacer()
                    Text(monthStart.formatted(.dateTime.month(.wide).year()))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                        .buttonStyle(.plain)
                }
                IagGrouped {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text(Date().formatted(.dateTime.day().month(.abbreviated).year()))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(open == nil ? "Out" : "In")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(IagTheme.onLeaf)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(open == nil ? Color.secondary : IagTheme.leaf, in: Capsule())
                        }
                        timeRow("In time", clockLabel(inTime))
                        timeRow("Out time", clockLabel(outTime))
                        timeRow("Last punch", clockLabel(outTime.isEmpty ? inTime : outTime))
                        HStack {
                            Text("Time spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(spent)
                                .font(.caption.weight(.semibold))
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "clock")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(IagTheme.leaf)
                                .frame(width: 40, height: 40)
                                .background(IagTheme.leaf.opacity(0.12), in: Circle())
                            Button {
                                if gps.latitude == nil { gps.useHq() }
                                let lat = gps.latitude ?? hqLatitude
                                let lng = gps.longitude ?? hqLongitude
                                message = store.punch(kind: open == nil ? "in" : "out", latitude: lat, longitude: lng, accuracy: gps.accuracy == 0 ? 12 : gps.accuracy)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(open == nil ? "Clock in" : "Clock out")
                                    Image(systemName: "arrow.right")
                                        .font(.caption.weight(.semibold))
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 40)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(IagTheme.leaf)
                            .disabled(!store.canClockIn)
                        }
                        if let message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                }
                workGrid([
                    ("\(presentDates.count)", "Present days", "\(fullDays) full · \(halfDays) half"),
                    ("\(counts.absent)", "Absent days", missedOut == 0 ? "No missed clock-out" : "\(missedOut) missed clock-out"),
                    ("\(leaveDates.count)", "Leaves", "This month"),
                    ("\(holidays.count)", "Holidays", holidays.isEmpty ? "None this month" : holidays.map(\.name).prefix(1).joined()),
                    ("\(counts.weeklyOff)", "Weekly off", "Weekend"),
                    ("\(counts.remaining)", "Remaining days", "Still to come"),
                ])
                if !queue.isEmpty {
                    SectionHeading(title: "Pending actions", detail: "\(queue.count)")
                    NavigationLink {
                        if queue.count == 1 {
                            RecordDetailView(recordId: queue[0].id)
                        } else {
                            EntityListView(moduleId: "payroll", entity: "Leave Requests")
                        }
                    } label: {
                        DeskRow(
                            title: "Leave approval",
                            subtitle: leaveSubtitle(queue),
                            systemName: "calendar",
                            color: IagTheme.leaf
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(IagTheme.hairline, lineWidth: 0.5))
                }
            }
            .iagPage()
        }
        .scrollIndicators(.hidden)
        .background(IagTheme.canvas.ignoresSafeArea())
        .iagBar("Attendance", subtitle: "Days")
        .onAppear { gps.refresh() }
    }

    private func monthCounts(days: [Date], present: Set<String>, leave: Set<String>, holidays: Set<String>) -> (absent: Int, weeklyOff: Int, remaining: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var absent = 0
        var weeklyOff = 0
        var remaining = 0
        for day in days {
            let key = isoDay(day)
            let start = calendar.startOfDay(for: day)
            let weekend = calendar.component(.weekday, from: day) == 1 || calendar.component(.weekday, from: day) == 7
            if calendar.isDateInToday(day) {
                if !present.contains(key) && !leave.contains(key) && !holidays.contains(key) { remaining += 1 }
                continue
            }
            if start > today {
                remaining += 1
                continue
            }
            if present.contains(key) || leave.contains(key) || holidays.contains(key) { continue }
            if weekend { weeklyOff += 1 } else { absent += 1 }
        }
        return (absent, weeklyOff, remaining)
    }

    private func shiftMonth(_ delta: Int) {
        anchor = Calendar.current.date(byAdding: .month, value: delta, to: anchor) ?? anchor
    }

    private func timeRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
        }
    }

    private func workGrid(_ cells: [(String, String, String)]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                VStack(spacing: 2) {
                    Text(cell.0)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(IagTheme.leaf)
                        .monospacedDigit()
                    Text(cell.1)
                        .font(.caption2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(cell.2)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, minHeight: 78)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
        }
        .background(IagTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(IagTheme.hairline, lineWidth: 0.5))
    }

    private func pendingLeave(_ store: ErpStore) -> [ErpRecord] {
        let name = store.user?.name ?? ""
        return store.forEntity("payroll", "Leave Requests").filter { rec in
            guard store.isOpenStatus(rec.status) else { return false }
            if store.canOpen("payroll") && store.canApprove { return true }
            guard !name.isEmpty else { return false }
            return rec.subtitle.localizedCaseInsensitiveContains(name)
                || rec.title.localizedCaseInsensitiveContains(name)
                || recordField(rec, "employee", "Employee").localizedCaseInsensitiveContains(name)
        }
    }

    private func leaveSubtitle(_ rows: [ErpRecord]) -> String {
        let first = rows[0].subtitle.split(separator: "·").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? rows[0].title
        if rows.count == 1 { return first }
        return "\(first) and \(rows.count - 1) more"
    }
}

private func isoDay(_ date: Date) -> String {
    let c = Calendar.current
    return String(format: "%04d-%02d-%02d", c.component(.year, from: date), c.component(.month, from: date), c.component(.day, from: date))
}

private func clockLabel(_ value: String) -> String {
    let parts = value.split(separator: ":").compactMap { Int($0) }
    guard parts.count >= 2 else { return "—" }
    let suffix = parts[0] >= 12 ? "PM" : "AM"
    let hour = parts[0] % 12 == 0 ? 12 : parts[0] % 12
    return String(format: "%d:%02d %@", hour, parts[1], suffix)
}

private func spentLabel(_ hours: String, inTime: String, outTime: String) -> String {
    if let value = Double(hours), value > 0 {
        let mins = Int((value * 60).rounded())
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }
    guard !inTime.isEmpty else { return "—" }
    if outTime.isEmpty { return "On the clock" }
    return hours.isEmpty ? "—" : hours
}
