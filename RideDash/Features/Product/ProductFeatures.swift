import MapKit
import SwiftData
import SwiftUI

// MARK: - Persistence models

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
        self.id = UUID()
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

    init(date: Date = .now, category: ExpenseCategory, amount: Double, odometerKm: Double? = nil, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.categoryRaw = category.rawValue
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

    init(date: Date = .now, kind: MaintenanceKind, odometerKm: Double, notes: String = "", nextDueKm: Double? = nil, nextDueDate: Date? = nil) {
        self.id = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
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

    init(date: Date = .now, odometerKm: Double, litres: Double, totalCost: Double, fullTank: Bool = true) {
        self.id = UUID()
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

    init(startedAt: Date = .now, endedAt: Date? = nil, destination: String = "", distanceKm: Double = 0, notes: String = "") {
        self.id = UUID()
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

    private var activeVehicle: Vehicle? { vehicles.first(where: \ .isActive) ?? vehicles.first }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.state.label)
                            .font(.headline)
                    }
                    Spacer()
                    Circle()
                        .fill(sessionIndicator)
                        .frame(width: 12, height: 12)
                }
            }

            if let vehicle = activeVehicle {
                Section("Active vehicle") {
                    LabeledContent(vehicle.name, value: "\(vehicle.odometerKm, specifier: "%.0f") km")
                    if !vehicle.registrationNumber.isEmpty {
                        LabeledContent("Registration", value: vehicle.registrationNumber)
                    }
                }
            }

            Section("Current navigation") {
                LabeledContent("Destination", value: navigation.destination?.name ?? "Not set")
                LabeledContent("Instruction", value: navigation.projectionState.maneuver)
                LabeledContent("Next turn", value: navigation.projectionState.distanceToManeuver)
            }

            Section("This month") {
                let calendar = Calendar.current
                let total = expenses
                    .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
                    .reduce(0) { $0 + $1.amount }
                LabeledContent("Expenses", value: total.formatted(.currency(code: currencyCode)))
            }
        }
        .navigationTitle("RideDash")
    }

    private var currencyCode: String { UserDefaults.standard.string(forKey: "settings.currency") ?? "INR" }

    private var sessionIndicator: Color {
        switch session.state {
        case .projecting, .navigationReady, .authenticated: return .green
        case .failed: return .red
        case .disconnected: return .secondary
        default: return .orange
        }
    }
}

// MARK: - Navigation screen

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
                MapUserLocationButton()
                MapCompass()
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
                        if navigation.isCalculating { ProgressView() } else { Image(systemName: "arrow.triangle.turn.up.right.diamond.fill") }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let error = navigation.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                if navigation.route != nil {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(navigation.projectionState.maneuver).font(.headline).lineLimit(1)
                            Text("\(navigation.projectionState.distanceToManeuver) · ETA \(navigation.projectionState.eta)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Apple Maps") { navigation.openInAppleMaps() }
                            .buttonStyle(.bordered)
                    }
                }

                if session.state == .authenticated || session.state == .navigationReady || session.state == .projecting {
                    HStack {
                        Button("Enter Dash Nav") {
                            Task { try? await session.enterNavigation(title: navigation.destination?.name ?? "Navigation") }
                        }
                        .buttonStyle(.bordered)

                        Button(streamer.state == .streaming ? "Streaming" : "Start Projection") {
                            startProjection(calibration: false)
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
            .padding()
            .background(.regularMaterial)
        }
        .navigationTitle("Navigation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { navigation.startLocation() }
    }

    private func startProjection(calibration: Bool) {
        var profile = DashProtocolProfile.publicReference
        profile.host = dashHost
        profile.broadcastHost = broadcastHost
        profile.fps = fps
        profile.bitrateKbps = bitrate
        do {
            try streamer.start(coordinator: session, profile: profile) {
                if calibration {
                    var state = navigation.projectionState
                    state.isCalibrationGrid = true
                    return state
                }
                return navigation.projectionState
            }
        } catch {
            session.log.append(error.localizedDescription, category: "projection", level: .error)
        }
    }
}

// MARK: - Display connection

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
    @State private var calibration = true

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
                .disabled(ssid.isEmpty)
                LabeledContent("Wi-Fi", value: wifi.status.description)
            }

            Section("Protocol profile") {
                TextField("Dash host", text: $host)
                TextField("Broadcast", text: $broadcastHost)
                Stepper("Control UDP \(controlPort)", value: $controlPort, in: 1...65535)
                Stepper("Input UDP \(inputPort)", value: $inputPort, in: 1...65535)
                Stepper("Video UDP \(videoPort)", value: $videoPort, in: 1...65535)
                Stepper("FPS \(fps)", value: $fps, in: 1...15)
                Stepper("Bitrate \(bitrate) kbps", value: $bitrate, in: 100...800, step: 25)
            }

            Section("Session") {
                TextField("Phone hostname", text: $hostname)
                LabeledContent("State", value: session.state.label)
                LabeledContent("RX", value: "\(session.transport.receivedPackets)")
                LabeledContent("TX", value: "\(session.transport.sentPackets)")

                Button("Connect + Authenticate") {
                    Task { await session.connect(ssid: ssid, hostname: hostname, profile: profile) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(ssid.isEmpty)

                if session.state == .authenticated || session.state == .navigationReady || session.state == .projecting {
                    Button("Enter Navigation Mode") {
                        Task { try? await session.enterNavigation(title: navigation.destination?.name ?? "RideDash") }
                    }
                }

                if session.state == .navigationReady || session.state == .projecting {
                    Toggle("Calibration grid", isOn: $calibration)
                    Button("Start H.264/RTP Projection") {
                        do {
                            try streamer.start(coordinator: session, profile: profile) {
                                var state = navigation.projectionState
                                state.isCalibrationGrid = calibration
                                return state
                            }
                        } catch {
                            session.log.append(error.localizedDescription, category: "projection", level: .error)
                        }
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
                LabeledContent("Frames", value: "\(streamer.renderedFrames)")
                LabeledContent("RTP packets", value: "\(streamer.sentRTPPackets)")
                LabeledContent("Encoded", value: ByteCountFormatter.string(fromByteCount: Int64(streamer.encodedBytes), countStyle: .file))
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
}

// MARK: - Vehicles

struct VehiclesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vehicle.name) private var vehicles: [Vehicle]
    @State private var showAdd = false

    var body: some View {
        List {
            if vehicles.isEmpty {
                ContentUnavailableView("No vehicles", systemImage: "motorcycle", description: Text("Add a motorcycle to track maintenance, expenses, and rides."))
            }
            ForEach(vehicles) { vehicle in
                NavigationLink {
                    VehicleDetailView(vehicle: vehicle)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vehicle.name).font(.headline)
                            Text("\(vehicle.odometerKm, specifier: "%.0f") km").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vehicle.isActive { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    }
                }
                .swipeActions(edge: .leading) {
                    Button("Active") { makeActive(vehicle) }.tint(.green)
                }
            }
            .onDelete { indexes in indexes.forEach { context.delete(vehicles[$0]) } }
        }
        .navigationTitle("Vehicles")
        .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showAdd) { AddVehicleView() }
    }

    private func makeActive(_ selected: Vehicle) {
        vehicles.forEach { $0.isActive = ($0.id == selected.id) }
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
                TextField("Odometer km", value: $odometer, format: .number).keyboardType(.decimalPad)
            }
            .navigationTitle("Add Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(Vehicle(name: name, registrationNumber: registration, odometerKm: odometer, isActive: vehicles.isEmpty))
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct VehicleDetailView: View {
    @Bindable var vehicle: Vehicle
    var body: some View {
        Form {
            TextField("Name", text: $vehicle.name)
            TextField("Registration", text: $vehicle.registrationNumber)
            TextField("Odometer km", value: $vehicle.odometerKm, format: .number).keyboardType(.decimalPad)
            Section("Documents") {
                OptionalDateEditor(title: "Insurance", date: $vehicle.insuranceExpiry)
                OptionalDateEditor(title: "PUC", date: $vehicle.pucExpiry)
                OptionalDateEditor(title: "Last service", date: $vehicle.lastServiceDate)
            }
            Toggle("Active vehicle", isOn: $vehicle.isActive)
        }
        .navigationTitle(vehicle.name)
    }
}

struct OptionalDateEditor: View {
    let title: String
    @Binding var date: Date?
    var body: some View {
        Toggle(title, isOn: Binding(get: { date != nil }, set: { date = $0 ? (date ?? .now) : nil }))
        if date != nil {
            DatePicker(title, selection: Binding(get: { date ?? .now }, set: { date = $0 }), displayedComponents: .date)
        }
    }
}

// MARK: - Garage

struct GarageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FuelLog.date, order: .reverse) private var fuel: [FuelLog]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var maintenance: [MaintenanceRecord]
    @State private var showFuel = false
    @State private var showMaintenance = false

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Fuel logs", value: "\(fuel.count)")
                LabeledContent("Maintenance", value: "\(maintenance.count)")
                LabeledContent("Calculated mileage", value: mileage.map { String(format: "%.1f km/L", $0) } ?? "Need 2 full-tank fills")
            }
            Section("Quick actions") {
                Button("Log fuel") { showFuel = true }
                Button("Log maintenance") { showMaintenance = true }
            }
            Section("Recent fuel") {
                ForEach(fuel.prefix(10)) { entry in
                    LabeledContent("\(entry.litres, specifier: "%.1f") L", value: "\(entry.odometerKm, specifier: "%.0f") km")
                }
                .onDelete { indexes in indexes.forEach { context.delete(fuel[$0]) } }
            }
            Section("Recent maintenance") {
                ForEach(maintenance.prefix(10)) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.kind.rawValue).font(.headline)
                        Text("\(entry.odometerKm, specifier: "%.0f") km · \(entry.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Garage")
        .sheet(isPresented: $showFuel) { AddFuelView() }
        .sheet(isPresented: $showMaintenance) { AddMaintenanceView() }
    }

    private var mileage: Double? {
        let full = fuel.filter(\.fullTank).sorted { $0.odometerKm < $1.odometerKm }
        guard full.count >= 2, let last = full.last else { return nil }
        let previous = full[full.count - 2]
        let distance = last.odometerKm - previous.odometerKm
        guard distance > 0, last.litres > 0 else { return nil }
        return distance / last.litres
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
                    }.disabled(litres <= 0)
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

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) { ForEach(MaintenanceKind.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Odometer km", value: $odometer, format: .number).keyboardType(.decimalPad)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Maintenance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { context.insert(MaintenanceRecord(kind: kind, odometerKm: odometer, notes: notes)); dismiss() }
                }
            }
        }
    }
}

// MARK: - Expenses

struct ExpensesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var category: ExpenseCategory?
    @State private var showAdd = false
    @AppStorage("settings.currency") private var currency = "INR"

    private var filtered: [Expense] { category.map { chosen in expenses.filter { $0.category == chosen } } ?? expenses }

    var body: some View {
        List {
            Section {
                LabeledContent("Total", value: filtered.reduce(0) { $0 + $1.amount }.formatted(.currency(code: currency)))
                Picker("Filter", selection: $category) {
                    Text("All").tag(ExpenseCategory?.none)
                    ForEach(ExpenseCategory.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
            }
            ForEach(filtered) { expense in
                HStack {
                    VStack(alignment: .leading) {
                        Text(expense.category.rawValue).font(.headline)
                        Text(expense.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(expense.amount.formatted(.currency(code: currency)))
                }
            }
            .onDelete { indexes in indexes.forEach { context.delete(filtered[$0]) } }
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: CSVExporter.expenses(expenses)) { Image(systemName: "square.and.arrow.up") }
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddExpenseView() }
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
                Picker("Category", selection: $category) { ForEach(ExpenseCategory.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Amount", value: $amount, format: .number).keyboardType(.decimalPad)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { context.insert(Expense(category: category, amount: amount, notes: notes)); dismiss() }.disabled(amount <= 0)
                }
            }
        }
    }
}

enum CSVExporter {
    static func expenses(_ expenses: [Expense]) -> String {
        var lines = ["Date,Category,Amount,OdometerKm,Notes"]
        let formatter = ISO8601DateFormatter()
        for item in expenses {
            lines.append([
                formatter.string(from: item.date),
                escape(item.category.rawValue),
                String(item.amount),
                item.odometerKm.map(String.init) ?? "",
                escape(item.notes)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Rides

struct RidesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RideRecord.startedAt, order: .reverse) private var rides: [RideRecord]
    @State private var showAdd = false

    var body: some View {
        List {
            if rides.isEmpty { ContentUnavailableView("No rides", systemImage: "road.lanes", description: Text("Completed projected rides can be saved here.")) }
            ForEach(rides) { ride in
                VStack(alignment: .leading) {
                    Text(ride.destination.isEmpty ? "Ride" : ride.destination).font(.headline)
                    Text("\(ride.distanceKm, specifier: "%.1f") km · \(ride.startedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .onDelete { indexes in indexes.forEach { context.delete(rides[$0]) } }
        }
        .navigationTitle("Rides")
        .toolbar { Button { showAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showAdd) { AddRideView() }
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
                ToolbarItem(placement: .confirmationAction) { Button("Save") { context.insert(RideRecord(destination: destination, distanceKm: distance)); dismiss() } }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("settings.currency") private var currency = "INR"
    @AppStorage("settings.distance") private var distanceUnit = "km"
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
            Section("iOS behavior") {
                Toggle("Request background navigation location", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "settings.backgroundLocation") },
                    set: { value in
                        UserDefaults.standard.set(value, forKey: "settings.backgroundLocation")
                        navigation.locationService.setBackgroundNavigationEnabled(value)
                    }
                ))
                Text("Background location is legitimate for active navigation but does not guarantee that iOS will keep H.264/UDP projection alive after device lock.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("About") {
                Text("RideDash is an independent ride/navigation companion designed around compatible Wi-Fi motorcycle displays. It does not implement ECU, brake, ABS, throttle, immobilizer, or other safety-critical vehicle control.")
                    .font(.caption)
            }
        }
        .navigationTitle("Settings")
    }
}
