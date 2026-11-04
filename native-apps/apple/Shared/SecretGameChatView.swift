#if os(iOS)
import SwiftUI

struct SecretGameChatView:View {
    @AppStorage("cloudclimb.secret0000.unlocked") private var unlocked=true
    @AppStorage("cloudClimb.twilightSky") private var twilight=false
    @AppStorage("cloudClimb.showTips") private var tips=true
    @AppStorage("cloudClimb.autoHideControls") private var autoHide=true
    @AppStorage("cloudclimb.secret.accent") private var accent="blue"
    @AppStorage("cloudclimb.secret.background") private var background="clouds"
    @State private var draft=""
    @State private var history=["Game: Type /help for customization commands."]
    private let colors=["blue","green","orange","pink","teal"]
    private let backgrounds=["clouds","sunset","stars","forest","ocean","space"]
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
            Text("Background: \(background) · Theme: \(accent) · Sky: \(twilight ? "twilight" : "day")")
                .font(.caption).foregroundStyle(.secondary)
        }.padding()
            .background(LinearGradient(colors:background=="sunset" ? [.orange,.pink] : background=="stars" ? [.black,.indigo] : background=="forest" ? [.green,.mint] : background=="ocean" ? [.cyan,.blue] : background=="space" ? [.indigo,.black] : [.cyan,.white],startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea())
            .navigationTitle("Secret Chat").onAppear {unlocked=true}
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
            reply="/background · /theme · /sky · /tips · /controls · /status · /reset · /cancel. Type a command to see options."
        case "/background":
            if parts.count==2 && backgrounds.contains(parts[1]) {background=parts[1];reply="Background saved."}
            else {reply="Choose: "+backgrounds.joined(separator:", ")}
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
            accent="blue";background="clouds";twilight=false;tips=true;autoHide=true;reply="Preferences reset."
        case "/cancel":
            if parts.count != 2 {reply="Choose: /cancel background, theme, sky, tips, controls, or all"}
            else {
                switch parts[1] {
                case "background":background="clouds";reply="Background restored."
                case "theme":accent="blue";reply="Theme restored."
                case "sky":twilight=false;reply="Sky restored."
                case "tips":tips=true;reply="Tips restored."
                case "controls":autoHide=true;reply="Controls restored."
                case "all":background="clouds";accent="blue";twilight=false;tips=true;autoHide=true;reply="All settings restored."
                default:reply="Type /cancel to see options."
                }
            }
        default:reply="Unknown command. Type /help."
        }
        history.append("Game: "+reply)
    }
}
#endif
