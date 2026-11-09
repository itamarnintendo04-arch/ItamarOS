import SwiftUI
import CoreImage.CIFilterBuiltins

struct BalanceTask: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var details: String
    var minutes: Int
    var repeatsDaily: Bool = true
    var approvedToday: String? = nil
}

@MainActor
final class BalanceFamilyStore: ObservableObject {
    @Published var tasks: [BalanceTask] = [] { didSet { save() } }
    @Published var age: Int = 13 { didSet { UserDefaults.standard.set(age, forKey: "balance.age") } }
    @Published var ageConfirmed = false { didSet { UserDefaults.standard.set(ageConfirmed, forKey: "balance.ageConfirmed") } }
    @Published var parentMode = false
    @Published var pairedParentCode = ""
    @Published var pairingCode: String = ""
    @Published var earnedMinutes = 0 { didSet { UserDefaults.standard.set(earnedMinutes, forKey: "balance.earnedMinutes") } }
    @Published var message = ""
    private let tasksKey = "balance.family.tasks.v1"
    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([BalanceTask].self, from: data) { tasks = decoded }
        else {
            tasks = [
                BalanceTask(name: "Read a book", details: "Enjoy reading for a while.", minutes: 15),
                BalanceTask(name: "Outdoor break", details: "Spend some comfortable time outdoors.", minutes: 10),
                BalanceTask(name: "Creative time", details: "Draw, write, or make something.", minutes: 15)
            ]
        }
        age = defaults.object(forKey: "balance.age") as? Int ?? 13
        ageConfirmed = defaults.bool(forKey: "balance.ageConfirmed")
        earnedMinutes = defaults.integer(forKey: "balance.earnedMinutes")
        pairedParentCode = defaults.string(forKey: "balance.pairedParentCode") ?? ""
        pairingCode = defaults.string(forKey: "balance.pairingCode") ?? UUID().uuidString
        defaults.set(pairingCode, forKey: "balance.pairingCode")
        save()
    }
    private func save() {
        if let data = try? JSONEncoder().encode(tasks) { UserDefaults.standard.set(data, forKey: tasksKey) }
    }
    var requiresParent: Bool { ageConfirmed && age < 13 }
    var isPaired: Bool { !pairedParentCode.isEmpty }
    var today: String { DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none) }
    func pairFromQR(_ code: String) {
        let prefix = "itamaros-screenbalance:v1:"
        guard code.hasPrefix(prefix),
              UUID(uuidString: String(code.dropFirst(prefix.count))) != nil else {
            message = "This is not a valid Screen Balance pairing QR."
            return
        }
        // This records a pending pairing locally only. It does not authorize another device.
        pairedParentCode = code
        UserDefaults.standard.set(code, forKey: "balance.pairedParentCode")
        message = "Pairing code scanned. Secure account verification and server sync are still required."
    }
    func approve(_ id: UUID, minutes: Int) {
        guard parentMode, let i = tasks.firstIndex(where: { $0.id == id }),
              tasks[i].approvedToday != today else { return }
        tasks[i].approvedToday = today
        earnedMinutes += max(1, min(240, minutes))
        message = "Task approved locally. \(minutes) reward minutes recorded, but iOS app limits were not changed."
    }
}

struct BalanceQRView: View {
    let code: String
    var body: some View {
        if let image = Self.generate(code) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityLabel("Pairing QR code")
        } else {
            Text("Unable to generate pairing code.")
        }
    }
    static func generate(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        let context = CIContext()
        guard let image = filter.outputImage,
              let cg = context.createCGImage(image.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
                                             from: image.extent.applying(CGAffineTransform(scaleX: 10, y: 10))) else { return nil }
        return UIImage(cgImage: cg)
    }
}

struct BalanceFamilyDashboard: View {
    @ObservedObject var store: BalanceFamilyStore
    @State private var editor = false
    @State private var editing: BalanceTask?
    @State private var taskName = ""
    @State private var taskDetails = ""
    @State private var reward = 15
    @State private var recurring = true
    @State private var approving: BalanceTask?
    @State private var approveMinutes = 15
    @State private var scan = false
    @State private var deleteTarget: BalanceTask?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(store.parentMode ? "Parent dashboard" : "My tasks").font(.title2.bold())
                Spacer()
                if store.parentMode {
                    Button("Add task", systemImage: "plus") { openEditor(nil) }
                        .buttonStyle(.borderedProminent)
                }
            }
            if store.parentMode {
                Text("Parent tools on this device. Remote management requires verified pairing and sync.")
                    .font(.caption).foregroundStyle(.orange)
                Button("Scan child's pairing QR", systemImage: "qrcode.viewfinder") { scan = true }
                    .buttonStyle(.bordered)
            } else if store.requiresParent {
                Text("A parent must approve completed tasks. Rewards are not automatically granted.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(store.tasks) { task in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.name).font(.headline)
                            if !task.details.isEmpty { Text(task.details).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text("\(task.minutes) min").font(.caption.bold()).foregroundStyle(.mint)
                    }
                    if task.approvedToday == store.today {
                        Label("Approved today", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if store.parentMode {
                        HStack {
                            Button("Approve completion") {
                                approving = task
                                approveMinutes = task.minutes
                            }.buttonStyle(.borderedProminent)
                            Button("Edit") { openEditor(task) }.buttonStyle(.bordered)
                            Button("Delete", role: .destructive) { deleteTarget = task }.buttonStyle(.bordered)
                        }.font(.caption)
                    } else {
                        Text("Awaiting parent approval").font(.caption).foregroundStyle(.secondary)
                    }
                    if task.repeatsDaily { Label("Daily task", systemImage: "repeat").font(.caption2).foregroundStyle(.secondary) }
                }
                .padding(15)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
            }
            Text("Recorded reward minutes: \(store.earnedMinutes)")
                .font(.subheadline.bold())
            if !store.message.isEmpty { Text(store.message).font(.caption).foregroundStyle(.orange) }
        }
        .sheet(isPresented: $editor) {
            NavigationStack {
                Form {
                    TextField("Task name", text: $taskName)
                    TextField("Description", text: $taskDetails)
                    Stepper("Reward: \(reward) minutes", value: $reward, in: 1...240)
                    Toggle("Repeat daily", isOn: $recurring)
                }
                .navigationTitle(editing == nil ? "New task" : "Edit task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editor = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let clean = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !clean.isEmpty else { return }
                            if let original = editing, let index = store.tasks.firstIndex(where: { $0.id == original.id }) {
                                store.tasks[index].name = clean
                                store.tasks[index].details = taskDetails
                                store.tasks[index].minutes = reward
                                store.tasks[index].repeatsDaily = recurring
                            } else {
                                store.tasks.append(BalanceTask(name: clean, details: taskDetails, minutes: reward, repeatsDaily: recurring))
                            }
                            editor = false
                        }.disabled(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { approving != nil }, set: { if !$0 { approving = nil } })) {
            NavigationStack {
                Form {
                    Text(approving?.name ?? "Task")
                    Stepper("Reward: \(approveMinutes) minutes", value: $approveMinutes, in: 1...240)
                    Button("Approve task") {
                        if let task = approving { store.approve(task.id, minutes: approveMinutes) }
                        approving = nil
                    }
                    Button("Cancel") { approving = nil }
                }
                .navigationTitle("Approve completion")
            }
        }
        .confirmationDialog("Delete this task?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })) {
            Button("Delete task", role: .destructive) {
                if let task = deleteTarget { store.tasks.removeAll { $0.id == task.id } }
                deleteTarget = nil
            }
        }
        .sheet(isPresented: $scan) {
            NavigationStack {
                BalanceQRScanner(onScan: { value in store.pairFromQR(value); scan = false },
                                 onFailure: { value in store.message = value; scan = false })
                    .navigationTitle("Scan child QR")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { scan = false } } }
            }
        }
    }
    private func openEditor(_ task: BalanceTask?) {
        editing = task
        taskName = task?.name ?? ""
        taskDetails = task?.details ?? ""
        reward = task?.minutes ?? 15
        recurring = task?.repeatsDaily ?? true
        editor = true
    }
}
