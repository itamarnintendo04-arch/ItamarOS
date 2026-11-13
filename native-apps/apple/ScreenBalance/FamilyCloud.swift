import SwiftUI
import Security

struct CloudBalanceTask: Codable, Identifiable {
    let id: UUID
    let child_id: UUID
    var name: String
    var details: String
    var reward_minutes: Int
    var recurring: Bool
}
struct CloudBalanceLink: Codable {
    let child_id: UUID
    let parent_id: UUID
}
struct CloudBalanceReward: Codable, Identifiable {
    let id: UUID
    let task_id: UUID
    let child_id: UUID
    let parent_id: UUID
    let reward_minutes: Int
    let approved_at: String
}
private struct CloudAuth: Codable {
    var access_token: String
    var refresh_token: String
    var expires_at: Date
    var user_id: UUID
}
private struct CloudUser: Decodable { let id: UUID }
private struct CloudAuthResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Double
    let user: CloudUser
}
private struct CloudRefreshResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Double
}
@MainActor
final class BalanceCloud: ObservableObject {
    @Published var authenticated = false
    @Published var loading = false
    @Published var status = ""
    @Published var tasks: [CloudBalanceTask] = []
    @Published var rewards: [CloudBalanceReward] = []
    @Published var linkedChild: UUID?
    @Published var linkedParent: UUID?
    @Published var pairingCode: UUID?
    private var auth: CloudAuth?
    private let keychainService = "org.itamaros.screenbalance.auth"
    private var base: String { Bundle.main.object(forInfoDictionaryKey: "ITAMAR_SUPABASE_URL") as? String ?? "" }
    private var apiKey: String { Bundle.main.object(forInfoDictionaryKey: "ITAMAR_SUPABASE_PUBLISHABLE_KEY") as? String ?? "" }
    var accountID: UUID? { auth?.user_id }

    init() {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:keychainService,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data { auth = try? JSONDecoder().decode(CloudAuth.self,from:data) }
    }
    private func save(_ value: CloudAuth) {
        auth = value
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:keychainService]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = try? JSONEncoder().encode(value)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary,nil)
        authenticated = true
    }
    private func call(_ path: String, method: String = "GET", body: Data? = nil, authenticatedRequest: Bool = true) async throws -> Data {
        guard let url = URL(string: base + path), url.scheme == "https", !apiKey.isEmpty else {
            throw NSError(domain:"ScreenBalance",code:1,userInfo:[NSLocalizedDescriptionKey:"ItamarOS account configuration missing"])
        }
        var request = URLRequest(url:url)
        request.httpMethod = method
        request.setValue(apiKey,forHTTPHeaderField:"apikey")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        if authenticatedRequest {
            guard let auth else { throw URLError(.userAuthenticationRequired) }
            request.setValue("Bearer " + auth.access_token,forHTTPHeaderField:"Authorization")
        }
        request.httpBody = body
        let (data,response) = try await URLSession.shared.data(for:request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data:data,encoding:.utf8) ?? "Server error"
            throw NSError(domain:"ScreenBalance",code:2,userInfo:[NSLocalizedDescriptionKey:String(message.prefix(250))])
        }
        return data
    }
    private func json(_ object: [String:Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject:object)
    }
    private func execute(_ work: () async throws -> Void) async {
        loading = true
        defer { loading = false }
        do { try await work() } catch { status = error.localizedDescription }
    }
    func signIn(email: String,password: String) async {
        await execute {
            let data = try await call("/auth/v1/token?grant_type=password",method:"POST",body:try json(["email":email,"password":password]),authenticatedRequest:false)
            let result = try JSONDecoder().decode(CloudAuthResponse.self,from:data)
            save(CloudAuth(access_token:result.access_token,refresh_token:result.refresh_token,expires_at:Date().addingTimeInterval(result.expires_in),user_id:result.user.id))
            status = "Signed in to ItamarOS"
            await refresh()
        }
    }
    func restore() async {
        guard let previous = auth else { return }
        await execute {
            let data = try await call("/auth/v1/token?grant_type=refresh_token",method:"POST",body:try json(["refresh_token":previous.refresh_token]),authenticatedRequest:false)
            let result = try JSONDecoder().decode(CloudRefreshResponse.self,from:data)
            save(CloudAuth(access_token:result.access_token,refresh_token:result.refresh_token,expires_at:Date().addingTimeInterval(result.expires_in),user_id:previous.user_id))
            await refresh()
        }
    }
    func signOut() {
        auth = nil
        authenticated = false
        tasks = []
        rewards = []
        linkedChild = nil
        linkedParent = nil
        pairingCode = nil
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:keychainService] as CFDictionary)
    }
    func refresh() async {
        guard let id = accountID else { return }
        await execute {
            let linkData = try await call("/rest/v1/balance_links?select=child_id,parent_id&or=(child_id.eq.\(id.uuidString),parent_id.eq.\(id.uuidString))")
            let links = try JSONDecoder().decode([CloudBalanceLink].self,from:linkData)
            linkedChild = links.first(where:{$0.parent_id == id})?.child_id
            linkedParent = links.first(where:{$0.child_id == id})?.parent_id
            let target = linkedChild ?? id
            let taskData = try await call("/rest/v1/balance_tasks?select=id,child_id,name,details,reward_minutes,recurring&child_id=eq.\(target.uuidString)&order=created_at.asc")
            tasks = try JSONDecoder().decode([CloudBalanceTask].self,from:taskData)
            let rewardData = try await call("/rest/v1/balance_rewards?select=id,task_id,child_id,parent_id,reward_minutes,approved_at&child_id=eq.\(target.uuidString)&order=approved_at.desc&limit=100")
            rewards = try JSONDecoder().decode([CloudBalanceReward].self,from:rewardData)
        }
    }
    func createPairing() async {
        guard let id = accountID else { return }
        await execute {
            let data = try await call("/rest/v1/balance_pairing_requests?select=code",method:"POST",body:try json(["child_id":id.uuidString]),authenticatedRequest:true)
            // PostgREST may return an empty body unless Prefer: return=representation is set.
            // Generate a UUID client-side to ensure a readable QR and submit it explicitly.
            _ = data
        }
    }
    func createPairingCode() async {
        guard let id = accountID else { return }
        let code = UUID()
        await execute {
            _ = try await call("/rest/v1/balance_pairing_requests",method:"POST",body:try json(["code":code.uuidString,"child_id":id.uuidString]))
            pairingCode = code
            status = "Pairing code created. Expires in 10 minutes."
        }
    }
    func claimPairing(_ code: String) async {
        guard let uuid = UUID(uuidString:code) else { status = "Invalid QR code"; return }
        await execute {
            _ = try await call("/rest/v1/rpc/balance_claim_pairing",method:"POST",body:try json(["p_code":uuid.uuidString]))
            status = "Accounts linked. Parent controls must still be authorized by Apple."
            await refresh()
        }
    }
    func addTask(name: String,details: String,minutes: Int,recurring: Bool) async {
        guard let child = linkedChild else { status = "Link a child account first"; return }
        await execute {
            _ = try await call("/rest/v1/balance_tasks",method:"POST",body:try json(["child_id":child.uuidString,"name":name,"details":details,"reward_minutes":minutes,"recurring":recurring]))
            await refresh()
        }
    }
    func updateTask(_ task: CloudBalanceTask,name: String,details: String,minutes: Int,recurring: Bool) async {
        guard linkedChild != nil else { return }
        await execute {
            _ = try await call("/rest/v1/balance_tasks?id=eq.\(task.id.uuidString)",method:"PATCH",body:try json(["name":name,"details":details,"reward_minutes":minutes,"recurring":recurring]))
            await refresh()
        }
    }
    func deleteTask(_ task: CloudBalanceTask) async {
        guard linkedChild != nil else { return }
        await execute {
            _ = try await call("/rest/v1/balance_tasks?id=eq.\(task.id.uuidString)",method:"DELETE")
            await refresh()
        }
    }
    func approve(_ task: CloudBalanceTask,minutes: Int) async {
        guard let parent = accountID,let child = linkedChild else { return }
        await execute {
            _ = try await call("/rest/v1/balance_rewards",method:"POST",body:try json(["task_id":task.id.uuidString,"parent_id":parent.uuidString,"child_id":child.uuidString,"reward_minutes":minutes]))
            status = "Reward approved. The child's device must sync before applying it."
            await refresh()
        }
    }
}

struct BalanceCloudPanel: View {
    @StateObject private var cloud = BalanceCloud()
    @State private var email = ""
    @State private var password = ""
    @State private var editing: CloudBalanceTask?
    @State private var name = ""
    @State private var details = ""
    @State private var minutes = 15
    @State private var recurring = true
    @State private var editor = false
    @State private var scan = false
    @State private var selected: CloudBalanceTask?
    @State private var reward = 15
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Family sync").font(.title2.bold())
            if !cloud.authenticated {
                TextField("ItamarOS email",text:$email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                SecureField("Password",text:$password)
                Button("Sign in with ItamarOS") { Task { await cloud.signIn(email:email,password:password) } }
                    .buttonStyle(.borderedProminent).disabled(cloud.loading || email.isEmpty || password.isEmpty)
            } else {
                HStack {
                    Text("Account connected").foregroundStyle(.green)
                    Spacer()
                    Button("Sync") { Task { await cloud.refresh() } }
                    Button("Sign out") { cloud.signOut() }
                }
                if cloud.linkedChild == nil && cloud.linkedParent == nil {
                    Button("Create child pairing QR") { Task { await cloud.createPairingCode() } }
                        .buttonStyle(.borderedProminent)
                    if let code = cloud.pairingCode {
                        BalanceQRView(code:"itamaros-screenbalance:v2:" + code.uuidString)
                        Text("Parent: scan this QR on your own signed-in device within 10 minutes.")
                            .font(.caption)
                    }
                    Button("Scan child's QR as parent") { scan = true }.buttonStyle(.bordered)
                }
                if cloud.linkedChild != nil {
                    HStack {
                        Text("Parent dashboard").font(.headline)
                        Spacer()
                        Button("Add task") { open(nil) }
                    }
                } else if cloud.linkedParent != nil {
                    Text("Child dashboard").font(.headline)
                }
                ForEach(cloud.tasks) { task in
                    VStack(alignment:.leading,spacing:6) {
                        Text(task.name).font(.headline)
                        Text(task.details).font(.caption).foregroundStyle(.secondary)
                        Text("Suggested reward: \(task.reward_minutes) min").foregroundStyle(.mint)
                        if cloud.linkedChild != nil {
                            HStack {
                                Button("Approve") { selected=task;reward=task.reward_minutes }
                                Button("Edit") { open(task) }
                                Button("Delete",role:.destructive) { Task { await cloud.deleteTask(task) } }
                            }.buttonStyle(.bordered)
                        }
                    }.padding().background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
                }
                Text("Approvals: \(cloud.rewards.count) recorded (latest 100)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if cloud.loading { ProgressView() }
            if !cloud.status.isEmpty { Text(cloud.status).font(.caption).foregroundStyle(.orange) }
            Text("Sync requires separate ItamarOS accounts. QR pairing verifies account possession, not legal guardianship. Apple Family Controls authorization is still required.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .sheet(isPresented:$editor) {
            NavigationStack {
                Form {
                    TextField("Task",text:$name)
                    TextField("Details",text:$details)
                    Stepper("Minutes: \(minutes)",value:$minutes,in:1...240)
                    Toggle("Daily",isOn:$recurring)
                }
                .navigationTitle(editing == nil ? "Add task" : "Edit task")
                .toolbar {
                    Button("Cancel") { editor=false }
                    Button("Save") {
                        let clean=name.trimmingCharacters(in:.whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        Task {
                            if let editing { await cloud.updateTask(editing,name:clean,details:details,minutes:minutes,recurring:recurring) }
                            else { await cloud.addTask(name:clean,details:details,minutes:minutes,recurring:recurring) }
                        }
                        editor=false
                    }
                }
            }
        }
        .sheet(isPresented:$scan) {
            NavigationStack {
                BalanceQRScanner(onScan:{ value in
                    scan=false
                    let prefix="itamaros-screenbalance:v2:"
                    if value.hasPrefix(prefix) { Task { await cloud.claimPairing(String(value.dropFirst(prefix.count))) } }
                    else { cloud.status="Invalid family pairing QR" }
                },onFailure:{ value in cloud.status=value;scan=false })
                .navigationTitle("Scan child QR")
                .toolbar { Button("Done") { scan=false } }
            }
        }
        .sheet(isPresented:Binding(get:{selected != nil},set:{if !$0 {selected=nil}})) {
            NavigationStack {
                Form {
                    Stepper("Reward: \(reward) min",value:$reward,in:1...240)
                    Button("Approve completion") {
                        if let task=selected { Task { await cloud.approve(task,minutes:reward) } }
                        selected=nil
                    }
                }.navigationTitle("Approve task")
            }
        }
        .task { await cloud.restore() }
    }
    private func open(_ task: CloudBalanceTask?) {
        editing=task
        name=task?.name ?? ""
        details=task?.details ?? ""
        minutes=task?.reward_minutes ?? 15
        recurring=task?.recurring ?? true
        editor=true
    }
}
