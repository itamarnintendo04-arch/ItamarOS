#if os(iOS)
import SwiftUI

struct SecretGameChatView:View {
    @AppStorage("cloudclimb.secret0000.unlocked") private var unlocked=true
    @AppStorage("cloudClimb.twilightSky") private var twilight=false
    @AppStorage("cloudClimb.showTips") private var tips=true
    @AppStorage("cloudClimb.autoHideControls") private var autoHide=true
    @AppStorage("cloudclimb.secret.accent") private var accent="blue"
    @State private var draft=""
    @State private var history=["Game: Type /help for customization commands."]
    private let colors=["blue","purple","green","orange","pink"]
    var body:some View {
        VStack(spacing:12) {
            Label("0000 · Secret Game Chat",systemImage:"gamecontroller.fill").font(.headline)
            ScrollView {
                LazyVStack(alignment:.leading,spacing:8) {
                    ForEach(history.indices,id:\.self) { index in
                        Text(history[index]).frame(maxWidth:.infinity,alignment:.leading)
                            .padding(10).background(.purple.opacity(0.10),in:RoundedRectangle(cornerRadius:12))
                    }
                }
            }
            HStack {
                TextField("Type /help",text:$draft).textInputAutocapitalization(.never)
                    .autocorrectionDisabled().textFieldStyle(.roundedBorder).onSubmit(send)
                Button("Send",action:send).disabled(draft.isEmpty)
            }
            Text("Theme: \(accent) · Sky: \(twilight ? "twilight" : "day")")
                .font(.caption).foregroundStyle(.secondary)
        }.padding().navigationTitle("Secret Chat").onAppear {unlocked=true}
    }
    private func send() {
        let input=draft.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        guard !input.isEmpty else{return}
        draft=""
        history.append("You: "+input)
        let parts=input.split(separator:" ").map(String.init)
        var reply=""
        switch parts.first {
        case "/help":
            reply="/theme blue|purple|green|orange|pink · /sky day|twilight · /tips on|off · /controls auto|always · /status · /reset · /cancel"
        case "/theme":
            if parts.count==2 && colors.contains(parts[1]) {accent=parts[1];reply="Theme saved."}
            else {reply="Choose: "+colors.joined(separator:", ")}
        case "/sky":
            if parts.count==2 && ["day","twilight"].contains(parts[1]) {
                twilight=parts[1]=="twilight";reply="Sky saved."
            } else {reply="Use /sky day or /sky twilight"}
        case "/tips":
            if parts.count==2 && ["on","off"].contains(parts[1]) {
                tips=parts[1]=="on";reply="Tips saved."
            } else {reply="Use /tips on or /tips off"}
        case "/controls":
            if parts.count==2 && ["auto","always"].contains(parts[1]) {
                autoHide=parts[1]=="auto";reply="Controls saved."
            } else {reply="Use /controls auto or /controls always"}
        case "/status":
            reply="Theme: \(accent), sky: \(twilight ? "twilight" : "day"), tips: \(tips ? "on" : "off")"
        case "/reset":
            accent="blue";twilight=false;tips=true;autoHide=true;reply="Preferences reset."
        case "/cancel":reply="No pending command."
        default:reply="Unknown command. Type /help."
        }
        history.append("Game: "+reply)
    }
}
#endif
