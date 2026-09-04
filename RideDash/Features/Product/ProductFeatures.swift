import MapKit
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Local models

@Model
final class Vehicle {
    var id: UUID
    var name: String
    var registrationNumber: String
    var odometerKm: Double
    var insuranceExpiry: Date?
    var pucExpiry: Date?
    var lastServiceDate: Date?
    var isActive: Bool

    init(
        name: String,
        registrationNumber: String = "",
        odometerKm: Double = 0,
        insuranceExpiry: Date? = nil,
        pucExpiry: Date? = nil,
        lastServiceDate: Date? = nil,
        isActive: Bool = false
    ) {
        id = UUID()
        self.name = name
        self.registrationNumber = registrationNumber
        self.odometerKm = odometerKm
        self.insuranceExpiry = insuranceExpiry
        self.pucExpiry = pucExpiry
        self.lastServiceDate = lastServiceDate
        self.isActive = isActive
    }
}

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case fuel = "Fuel"
    case service = "Service"
    case repair = "Repair"
    case accessory = "Accessory"
    case gear = "Riding Gear"
    case food = "Food"
    case stay = "Stay"
    case transport = "Transport"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class Expense {
    var id: UUID
    var date: Date
    var categoryRaw: String
    var amount: Double
    var odometerKm: Double?
    var notes: String

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        category: ExpenseCategory,
        amount: Double,
        odometerKm: Double? = nil,
        notes: String = ""
    ) {
        id = UUID()
        self.date = date
        categoryRaw = category.rawValue
        self.amount = amount
        self.odometerKm = odometerKm
        self.notes = notes
    }
}

enum MaintenanceKind: String, CaseIterable, Identifiable, Codable {
    case service = "Service"
    case chainClean = "Chain Clean"
    case chainLube = "Chain Lube"
    case tyre = "Tyre"
    case brake = "Brake"
    case accessory = "Accessory"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class MaintenanceRecord {
    var id: UUID
    var date: Date
    var kindRaw: String
    var odometerKm: Double
    var notes: String
    var nextDueKm: Double?
    var nextDueDate: Date?

    var kind: MaintenanceKind {
        get { MaintenanceKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        kind: MaintenanceKind,
        odometerKm: Double,
        notes: String = "",
        nextDueKm: Double? = nil,
        nextDueDate: Date? = nil
    ) {
        id = UUID()
        self.date = date
        kindRaw = kind.rawValue
        self.odometerKm = odometerKm
        self.notes = notes
        self.nextDueKm = nextDueKm
        self.nextDueDate = nextDueDate
    }
}

@Model
final class FuelLog {
    var id: UUID
    var date: Date
    var odometerKm: Double
    var litres: Double
    var totalCost: Double
    var fullTank: Bool

    init(
        date: Date = .now,
        odometerKm: Double,
        litres: Double,
        totalCost: Double,
        fullTank: Bool = true
    ) {
        id = UUID()
        self.date = date
        self.odometerKm = odometerKm
        self.litres = litres
        self.totalCost = totalCost
        self.fullTank = fullTank
    }
}

@Model
final class RideRecord {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var destination: String
    var distanceKm: Double
    var notes: String

    init(
        startedAt: Date = .now,
        endedAt: Date? = nil,
        destination: String = "",
        distanceKm: Double = 0,
        notes: String = ""
    ) {
        id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.destination = destination
        self.distanceKm = distanceKm
        self.notes = notes
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject private var session: DashSessionCoordinator
    @EnvironmentObject private var navigation: NavigationViewModel
    @Query(sort: \Vehicle.name) private var vehicles: [Vehicle]
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @AppStorage("settings.currency") private var currency = "INR"

    private var activeVehicle: Vehicle? {
        vehicles.first(where: { $0.isActive }) ?? vehicles.first
    }

    var body: some View {
        List {
            Section("Display") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.state.label).font(.headline)
                        Text("RX \(session.transport.receivedPackets) · TX \(session.transport.sentPackets)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 12, height: 12)
                }
                if session.reconnectAttempt > 0 {
                    LabeledContent("Reconnect", value: "\(session.reconnectAttempt)/5")
                }
            }

            Section("Active vehicle") {
                if let vehicle = activeVehicle {
                    LabeledContent(vehicle.name, value: "\(vehicle.odometerKm, specifier: "%.0f") km")
                    if !vehicle.registrationNumber.isEmpty {
                        LabeledContent("Registration", value: vehicle.registrationNumber)
                    }
                } else {
                    Text("Add a vehicle from Settings → Vehicles")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Navigation") {
                LabeledContent("Destination", value: navigation.destination?.name ?? "Not set")
                LabeledContent("Instruction", value: navigation.projectionState.maneuver)
                LabeledContent("Next turn", value: navigation.projectionState.distanceToManeuver)
                if navigation.recalculationCount > 0 {
                    LabeledContent("Reroutes", value: "\(navigation.recalculationCount)")
                }
            }

            Section("This month") {
                LabeledContent("Expenses", value: currentMonthSpend.formatted(.currency(code: currency)))
            }
        }
        .navigationTitle("RideDash")
    }

    private var currentMonthSpend: Double {
        let calendar = Calendar.current
        return expenses
            .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    private var connectionColor: Color {
        switch session.state {
        case .projecting, .navigationReady, .authenticated: return .green
        case .failed: return .red
        case .disconnected: return .secondary
        default: return .orange
        }
    }
}

// MARK: - Route UI

struct RideNavigationView: View {
    @EnvironmentObject private var navigation: NavigationViewModel
    @EnvironmentObject private var session: DashSessionCoordinator
    @EnvironmentObject private var streamer: ProjectionStreamer

    @AppStorage("dash.profile.host") private var dashHost = "192.168.1.1"
    @AppStorage("dash.profile.broadcast") private var broadcastHost = "192.168.1.255"
    @AppStorage("dash.profile.fps") private var fps = 4
    @AppStorage("dash.profile.bitrate") private var bitrate = 250

    var body: some View {
        VStack(spacing: 0) {
            Map {
                UserAnnotation()
                if let destination = navigation.destination {
                    Marker(destination.name, coordinate: destination.coordinate)
                }
                if let route = navigation.route {
                    MapPolyline(route.polyline)
                        .stroke(.orange, lineWidth: 6)
                }
            }
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 10) {
                HStack {
                    TextField("Destination, coordinates, or map URL", text: $navigation.destinationInput)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                    Button {
                        Task { await navigation.calculateRoute() }
                    } label: {
                        if navigation.isCalculating || navigation.isRecalculating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let error = navigation.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                if navigation.route != nil {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(navigation.projectionState.maneuver)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(navigation.projectionState.distanceToManeuver) · ETA \(navigation.projectionState.eta)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if navigation.isRecalculating {
                                Text("Recalculating route…")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        Button("Apple Maps") { navigation.openInAppleMaps() }
                            .buttonStyle(.bordered)
                    }
                }

                displayActions
            }
            .padding()
            .background(.regularMaterial)
        }
        .navigationTitle("Navigation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { navigation.startLocation() }
    }

    @ViewBuilder
    private var displayActions: some View {
        if session.state == .authenticated || session.state == .navigationReady || session.state == .projecting {
            HStack {
                Button("Dash Nav") {
                    Task {
                        try? await session.enterNavigation(title: navigation.destination?.name ?? "Navigation")
                    }
                }
                .buttonStyle(.bordered)

                Button(streamer.state == .streaming ? "Streaming" : "Project") {
                    startProjection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.state != .navigationReady && session.state != .projecting)

                Button("Stop", role: .destructive) {
                    streamer.stop()
                    Task { await session.stopProjection() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func startProjection() {
        var profile = DashProtocolProfile.publicReference
        profile.host = dashHost
        profile.broadcastHost = broadcastHost
        profile.fps = fps
        profile.bitrateKbps = bitrate

        do {
            try streamer.start(coordinator: session, profile: profile) {
                navigation.projectionState
            }
        } catch {
            session.log.append(error.localizedDescription, category: "projection", level: .error)
        }
    }
}

// MARK: - Display connection / projection lab

struct DisplayConnectionView: View {
    @EnvironmentObject private var session: DashSessionCoordinator
    @EnvironmentObject private var navigation: NavigationViewModel
    @EnvironmentObject private var streamer: ProjectionStreamer
    @StateObject private var wifi = TripperWiFiManager()

    @AppStorage("dash.test.ssid") private var ssid = ""
    @AppStorage("dash.profile.host") private var host = "192.168.1.1"
    @AppStorage("dash.profile.broadcast") private var broadcastHost = "192.168.1.255"
    @AppStorage("dash.profile.controlPort") private var controlPort = 2000
    @AppStorage("dash.profile.inputPort") private var inputPort = 2002
    @AppStorage("dash.profile.videoPort") private var videoPort = 5000
    @AppStorage("dash.profile.fps") private var fps = 4
    @AppStorage("dash.profile.bitrate") private var bitrate = 250

    @State private var passphrase = ""
    @State private var hostname = UIDevice.current.name
    @State private var calibrationGrid = true

    var body: some View {
        Form {
            Section("Compatible display Wi-Fi") {
                TextField("SSID", text: $ssid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $passphrase)
                Button("Join Wi-Fi") {
                    Task {
                        do {
                            try await wifi.join(ssid: ssid, passphrase: passphrase)
                            passphrase = ""
                        } catch {
                            session.log.append(error.localizedDescription, category: "wifi", level: .error)
                        }
                    }
                }
                .disabled(ssid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                LabeledContent("Wi-Fi", value: wifi.status.description)
            }

            Section("Protocol profile") {
                TextField("Dash host", text: $host)
                    .textInputAutocapitalization(.never)
                TextField("Broadcast", text: $broadcastHost)
                    .textInputAutocapitalization(.never)
                Stepper("Control UDP \(controlPort)", value: $controlPort, in: 1...65_535)
                Stepper("Input UDP \(inputPort)", value: $inputPort, in: 1...65_535)
                Stepper("Video UDP \(videoPort)", value: $videoPort, in: 1...65_535)
                Stepper("FPS \(fps)", value: $fps, in: 1...15)
                Stepper("Bitrate \(bitrate) kbps", value: $bitrate, in: 100...800, step: 25)
            }

            Section("Session") {
                TextField("Phone hostname", text: $hostname)
                Toggle("Automatic reconnect", isOn: $session.automaticReconnectEnabled)
                LabeledContent("State", value: session.state.label)
                LabeledContent("RX packets", value: "\(session.transport.receivedPackets)")
                LabeledContent("TX packets", value: "\(session.transport.sentPackets)")
                if session.reconnectAttempt > 0 {
                    LabeledContent("Reconnect attempt", value: "\(session.reconnectAttempt)/5")
                }
                if let reason = session.lastReconnectReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let button = session.lastButton {
                    LabeledContent("Last dash input", value: String(describing: button))
                }

                Button("Connect + Authenticate") {
                    Task {
                        await session.connect(ssid: ssid, hostname: hostname, profile: profile)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(ssid.isEmpty)

                if session.state == .authenticated || session.state == .navigationReady || session.state == .projecting {
                    Button("Enter Navigation Mode") {
                        Task {
                            try? await session.enterNavigation(title: navigation.destination?.name ?? "RideDash")
                        }
                    }
                }

                if session.state == .navigationReady || session.state == .projecting {
                    Toggle("Calibration grid", isOn: $calibrationGrid)
                    Button("Start H.264/RTP Projection") {
                        startProjection()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Stop Projection", role: .destructive) {
                    streamer.stop()
                    Task { await session.stopProjection() }
                }

                Button("Disconnect", role: .destructive) {
                    streamer.stop()
                    session.disconnect()
                }
            }

            Section("Stream metrics") {
                LabeledContent("State", value: String(describing: streamer.state))
                LabeledContent("Rendered frames", value: "\(streamer.renderedFrames)")
                LabeledContent("RTP packets", value: "\(streamer.sentRTPPackets)")
                LabeledContent(
                    "Encoded",
                    value: ByteCountFormatter.string(fromByteCount: Int64(streamer.encodedBytes), countStyle: .file)
                )
            }
        }
        .navigationTitle("Display")
    }

    private var profile: DashProtocolProfile {
        DashProtocolProfile(
            host: host,
            broadcastHost: broadcastHost,
            controlPort: UInt16(clamping: controlPort),
            inputPort: UInt16(clamping: inputPort),
            videoPort: UInt16(clamping: videoPort),
            renderWidth: 526,
            renderHeight: 300,
            fps: fps,
            bitrateKbps: bitrate,
            respondToInput: true
        )
    }

    private func startProjection() {
        do {
            try streamer.start(coordinator: session, profile: profile) {
                var state = navigation.projectionState
                state.isCalibrationGrid = calibrationGrid
                return state
            }
        } catch {
            session.log.append(error.localizedDescription, category: "projection", level: .error)
        }
    }
}

// MARK: - Vehicles

struct VehiclesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vehicle.name) private var vehicles: [Vehicle]
    @State private var showingAdd = false

    var body: some View {
        List {
            if vehicles.isEmpty {
                ContentUnavailableView(
                    "No vehicles",
                    systemImage: "motorcycle",
                    description: Text("Add a motorcycle to track maintenance, expenses and rides.")
                )
            }

            ForEach(vehicles) { vehicle in
                NavigationLink {
                    VehicleDetailView(vehicle: vehicle)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vehicle.name).font(.headline)
                            Text("\(vehicle.odometerKm, specifier: "%.0f") km")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vehicle.isActive {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    Button("Active") { makeActive(vehicle) }
                        .tint(.green)
                }
            }
            .onDelete { offsets in
                offsets.forEach { context.delete(vehicles[$0]) }
            }
        }
        .navigationTitle("Vehicles")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) { AddVehicleView() }
    }

    private func makeActive(_ selected: Vehicle) {
        vehicles.forEach { $0.isActive = $0.id == selected.id }
    }
}

struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var vehicles: [Vehicle]

    @State private var name = ""
    @State private var registration = ""
    @State private var odometer = 0.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Vehicle name", text: $name)
                TextField("Registration", text: $registration)
                TextField("Odometer km", value: $odometer, format: .number)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(
                            Vehicle(
                                name: name,
                                registrationNumber: registration,
                                odometerKm: odometer,
                                isActive: vehicles.isEmpty
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct VehicleDetailView: View {
    @Bindable var vehicle: Vehicle

    var body: some View {
        Form {
            Section("Vehicle") {
                TextField("Name", text: $vehicle.name)
                TextField("Registration", text: $vehicle.registrationNumber)
                TextField("Odometer km", value: $vehicle.odometerKm, format: .number)
                    .keyboardType(.decimalPad)
            }
            Section("Documents") {
                OptionalDateEditor(title: "Insurance expiry", date: $vehicle.insuranceExpiry)
                OptionalDateEditor(title: "PUC expiry", date: $vehicle.pucExpiry)
                OptionalDateEditor(title: "Last service", date: $vehicle.lastServiceDate)
            }
        }
        .navigationTitle(vehicle.name)
    }
}

struct OptionalDateEditor: View {
    let title: String
    @Binding var date: Date?

    var body: some View {
        Toggle(
            title,
            isOn: Binding(
                get: { date != nil },
                set: { date = $0 ? (date ?? .now) : nil }
            )
        )
        if date != nil {
            DatePicker(
                title,
                selection: Binding(get: { date ?? .now }, set: { date = $0 }),
                displayedComponents: .date
            )
        }
    }
}

// MARK: - Garage

struct GarageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FuelLog.date, order: .reverse) private var fuelLogs: [FuelLog]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var maintenance: [MaintenanceRecord]
    @State private var showingFuel = false
    @State private var showingMaintenance = false

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Fuel logs", value: "\(fuelLogs.count)")
                LabeledContent("Maintenance logs", value: "\(maintenance.count)")
                LabeledContent(
                    "Calculated mileage",
                    value: mileage.map { String(format: "%.1f km/L", $0) } ?? "Need 2 full tanks"
                )
            }

            Section("Quick actions") {
                Button("Log fuel") { showingFuel = true }
                Button("Log maintenance") { showingMaintenance = true }
            }

            Section("Recent fuel") {
                ForEach(Array(fuelLogs.prefix(10))) { entry in
                    LabeledContent(
                        "\(entry.litres, specifier: "%.1f") L",
                        value: "\(entry.odometerKm, specifier: "%.0f") km"
                    )
                }
            }

            Section("Recent maintenance") {
                ForEach(Array(maintenance.prefix(10))) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.kind.rawValue).font(.headline)
                        Text("\(entry.odometerKm, specifier: "%.0f") km · \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let dueDate = entry.nextDueDate {
                            Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else if let dueKm = entry.nextDueKm {
                            Text("Due at \(dueKm, specifier: "%.0f") km")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Garage")
        .sheet(isPresented: $showingFuel) { AddFuelView() }
        .sheet(isPresented: $showingMaintenance) { AddMaintenanceView() }
    }

    private var mileage: Double? {
        let fullTanks = fuelLogs
            .filter { $0.fullTank }
            .sorted { $0.odometerKm < $1.odometerKm }
        guard fullTanks.count >= 2,
              let latest = fullTanks.last else { return nil }
        let previous = fullTanks[fullTanks.count - 2]
        let distance = latest.odometerKm - previous.odometerKm
        guard distance > 0, latest.litres > 0 else { return nil }
        return distance / latest.litres
    }
}

struct AddFuelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var odometer = 0.0
    @State private var litres = 0.0
    @State private var cost = 0.0
    @State private var fullTank = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Odometer km", value: $odometer, format: .number).keyboardType(.decimalPad)
                TextField("Litres", value: $litres, format: .number).keyboardType(.decimalPad)
                TextField("Total cost", value: $cost, format: .number).keyboardType(.decimalPad)
                Toggle("Full tank", isOn: $fullTank)
            }
            .navigationTitle("Fuel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(FuelLog(odometerKm: odometer, litres: litres, totalCost: cost, fullTank: fullTank))
                        context.insert(Expense(category: .fuel, amount: cost, odometerKm: odometer, notes: "Fuel log"))
                        dismiss()
                    }
                    .disabled(litres <= 0)
                }
            }
        }
    }
}

struct AddMaintenanceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var kind: MaintenanceKind = .service
    @State private var odometer = 0.0
    @State private var notes = ""
    @State private var nextDueKmEnabled = false
    @State private var nextDueKm = 0.0
    @State private var nextDueDateEnabled = false
    @State private var nextDueDate = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Maintenance") {
                    Picker("Type", selection: $kind) {
                        ForEach(MaintenanceKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Odometer km", value: $odometer, format: .number).keyboardType(.decimalPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                Section("Next due") {
                    Toggle("Track next due odometer", isOn: $nextDueKmEnabled)
                    if nextDueKmEnabled {
                        TextField("Next due km", value: $nextDueKm, format: .number)
                            .keyboardType(.decimalPad)
                    }

                    Toggle("Remind on a date", isOn: $nextDueDateEnabled)
                    if nextDueDateEnabled {
                        DatePicker("Due date", selection: $nextDueDate, displayedComponents: .date)
                        Text("RideDash will request notification permission when you save this reminder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Maintenance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let record = MaintenanceRecord(
                            kind: kind,
                            odometerKm: odometer,
                            notes: notes,
                            nextDueKm: nextDueKmEnabled ? nextDueKm : nil,
                            nextDueDate: nextDueDateEnabled ? nextDueDate : nil
                        )
                        context.insert(record)
                        if nextDueDateEnabled {
                            Task {
                                await MaintenanceReminderScheduler.schedule(
                                    id: record.id,
                                    title: record.kind.rawValue,
                                    dueDate: nextDueDate
                                )
                            }
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

enum MaintenanceReminderScheduler {
    static func schedule(id: UUID, title: String, dueDate: Date) async {
        guard dueDate > .now else { return }
        let center = UNUserNotificationCenter.current()

        do {
            let settings = await center.notificationSettings()
            var authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            if settings.authorizationStatus == .notDetermined {
                authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            guard authorized else { return }

            let identifier = "maintenance-\(id.uuidString)"
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = "Maintenance due"
            content.body = "\(title) is due today. Open RideDash to review your garage log."
            content.sound = .default

            var components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            components.hour = 9
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            // Reminder failure must never block saving maintenance history.
        }
    }

    static func cancel(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["maintenance-\(id.uuidString)"]
        )
    }
}

// MARK: - Expenses

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var selectedCategory: ExpenseCategory?
    @State private var showingAdd = false
    @AppStorage("settings.currency") private var currency = "INR"

    private var filtered: [Expense] {
        guard let selectedCategory else { return expenses }
        return expenses.filter { $0.category == selectedCategory }
    }

    var body: some View {
        List {
            Section {
                LabeledContent(
                    "Total",
                    value: filtered.reduce(0) { $0 + $1.amount }.formatted(.currency(code: currency))
                )
                Picker("Filter", selection: $selectedCategory) {
                    Text("All").tag(Optional<ExpenseCategory>.none)
                    ForEach(ExpenseCategory.allCases) { category in
                        Text(category.rawValue).tag(Optional(category))
                    }
                }
            }

            ForEach(filtered) { expense in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.category.rawValue).font(.headline)
                        Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(expense.amount.formatted(.currency(code: currency)))
                }
            }
            .onDelete { offsets in
                offsets.forEach { context.delete(filtered[$0]) }
            }
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: CSVExporter.expenses(expenses)) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) { AddExpenseView() }
    }
}

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var category: ExpenseCategory = .other
    @State private var amount = 0.0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Amount", value: $amount, format: .number).keyboardType(.decimalPad)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(Expense(category: category, amount: amount, notes: notes))
                        dismiss()
                    }
                    .disabled(amount <= 0)
                }
            }
        }
    }
}

enum CSVExporter {
    static func expenses(_ expenses: [Expense]) -> String {
        let formatter = ISO8601DateFormatter()
        var rows = ["Date,Category,Amount,OdometerKm,Notes"]
        for item in expenses {
            rows.append([
                formatter.string(from: item.date),
                escape(item.category.rawValue),
                String(item.amount),
                item.odometerKm.map { String($0) } ?? "",
                escape(item.notes)
            ].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Rides

struct RidesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RideRecord.startedAt, order: .reverse) private var rides: [RideRecord]
    @State private var showingAdd = false

    var body: some View {
        List {
            if rides.isEmpty {
                ContentUnavailableView(
                    "No rides",
                    systemImage: "road.lanes",
                    description: Text("Save completed rides here.")
                )
            }
            ForEach(rides) { ride in
                VStack(alignment: .leading, spacing: 3) {
                    Text(ride.destination.isEmpty ? "Ride" : ride.destination).font(.headline)
                    Text("\(ride.distanceKm, specifier: "%.1f") km · \(ride.startedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                offsets.forEach { context.delete(rides[$0]) }
            }
        }
        .navigationTitle("Rides")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) { AddRideView() }
    }
}

struct AddRideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var destination = ""
    @State private var distance = 0.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Destination", text: $destination)
                TextField("Distance km", value: $distance, format: .number).keyboardType(.decimalPad)
            }
            .navigationTitle("Ride")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(RideRecord(destination: destination, distanceKm: distance))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("settings.currency") private var currency = "INR"
    @AppStorage("settings.distance") private var distanceUnit = "km"
    @AppStorage("settings.backgroundLocation") private var backgroundLocation = false
    @EnvironmentObject private var navigation: NavigationViewModel

    var body: some View {
        Form {
            Section("Units") {
                Picker("Currency", selection: $currency) {
                    Text("INR ₹").tag("INR")
                    Text("USD $").tag("USD")
                    Text("EUR €").tag("EUR")
                    Text("GBP £").tag("GBP")
                }
                Picker("Distance", selection: $distanceUnit) {
                    Text("Kilometres").tag("km")
                    Text("Miles").tag("mi")
                }
            }

            Section("Display integration") {
                NavigationLink("Connection & Projection") { DisplayConnectionView() }
                NavigationLink("Diagnostics") { DiagnosticsView() }
                NavigationLink("Vehicles") { VehiclesView() }
            }

            Section("Navigation behavior") {
                Toggle("Background navigation location", isOn: $backgroundLocation)
                    .onChange(of: backgroundLocation) { _, enabled in
                        navigation.locationService.setBackgroundNavigationEnabled(enabled)
                    }
                Text("Location background mode supports active navigation. iOS may still suspend video encoding/network projection after device lock; verify this manually on your iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Maintenance reminders") {
                Text("When a maintenance entry includes a due date, RideDash schedules a local notification for 9:00 AM on that date after you grant notification permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Safety") {
                Text("RideDash limits display integration to navigation/infotainment. It does not send ECU, throttle, brake, ABS, immobilizer or other safety-critical vehicle-control commands.")
                    .font(.caption)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            navigation.locationService.setBackgroundNavigationEnabled(backgroundLocation)
        }
    }
}
