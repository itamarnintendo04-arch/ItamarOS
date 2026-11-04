#if os(iOS)
import SwiftUI
import LocalAuthentication
import AVFoundation

struct ItamarDesktopPairRoute: Identifiable {
    let request: String
    var isCloudClimb:Bool = false
    var id: String { request }
}

struct ItamarDesktopPairApprovalView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let request: String
    var isCloudClimb:Bool = false
    @State private var busy = false
    @State private var result = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(isCloudClimb ? "Approve Cloud Climb" : "Approve This Computer") {
                    Text(isCloudClimb
                        ? "Connect Cloud Climb using your existing ItamarOS account without scanning a QR code."
                        : "Use your existing ItamarOS Connect account to sign in on your computer without another SMS.")
                    Text(isCloudClimb
                        ? "Compare this code with the one displayed in Cloud Climb:"
                        : "Compare this code with the one displayed on your computer:")
                    Text(String(request.prefix(6)).uppercased())
                        .font(.system(.title,design:.monospaced)).bold()
                    Text(isCloudClimb
                        ? "Only approve a Cloud Climb login you started. Face ID or Touch ID is required; the linked app receives temporary account access."
                        : "Only approve a computer you are using. Biometric confirmation is required. Only approve a device you recognize; a pending desktop login can access your account.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    if cloud.isSignedIn {
                        Button(busy ? "Approving…" :
                            (isCloudClimb ? "Approve Cloud Climb" : "Approve This Computer")) {
                            busy = true
                            Task {
                                do {
                                    let verifier=LAContext()
                                    var authError:NSError?
                                    guard verifier.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                                     error:&authError) else {
                                        throw NSError(domain:"ItamarOSApproval",code:1,userInfo:[
                                            NSLocalizedDescriptionKey:"Face ID or Touch ID must be set up before approving."
                                        ])
                                    }
                                    let passed=try await verifier.evaluatePolicy(
                                        .deviceOwnerAuthenticationWithBiometrics,
                                        localizedReason:isCloudClimb
                                            ? "Confirm connecting Cloud Climb with your ItamarOS account"
                                            : "Approve a login on another device using your ItamarOS account")
                                    guard passed else {
                                        throw NSError(domain:"ItamarOSApproval",code:2,userInfo:[
                                            NSLocalizedDescriptionKey:"Biometric authentication was not completed."
                                        ])
                                    }
                                    try await cloud.approveDesktopPairing(request:request)
                                    result = isCloudClimb
                                        ? "Approved. Return to Cloud Climb to finish sign-in."
                                        : "Approved. Return to your computer."
                                } catch { result = error.localizedDescription }
                                busy = false
                            }
                        }.disabled(busy || result.hasPrefix("Approved"))
                    } else {
                        Text("Sign in to ItamarOS Connect on this phone first.")
                    }
                    if !result.isEmpty { Text(result).font(.caption) }
                    if isCloudClimb && result.hasPrefix("Approved") {
                        Button("Return to Cloud Climb") {
                            if let url=URL(string:"cloudclimb://login-return"){
                                openURL(url)
                            }
                        }
                    }
                    Button("Cancel",role:.cancel) { dismiss() }
                }
            }.navigationTitle(isCloudClimb ? "Cloud Climb Login" : "Desktop Login")
        }
    }
}

private struct ItamarQRReader: UIViewControllerRepresentable {
    let onCode:(String)->Void
    func makeUIViewController(context:Context)->UIViewController {
        let controller=UIViewController()
        controller.view.backgroundColor = .black
        let session=AVCaptureSession()
        guard let device=AVCaptureDevice.default(for:.video),
              let input=try? AVCaptureDeviceInput(device:device),
              session.canAddInput(input) else {return controller}
        session.addInput(input)
        let output=AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {return controller}
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator,queue:.main)
        output.metadataObjectTypes=[.qr]
        let layer=AVCaptureVideoPreviewLayer(session:session)
        layer.videoGravity = .resizeAspectFill
        layer.frame=controller.view.bounds
        controller.view.layer.addSublayer(layer)
        context.coordinator.session=session
        DispatchQueue.global(qos:.userInitiated).async {session.startRunning()}
        return controller
    }
    func updateUIViewController(_ controller:UIViewController,context:Context) {
        if let layer=controller.view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame=controller.view.bounds
        }
    }
    func makeCoordinator()->Coordinator {Coordinator(onCode:onCode)}
    static func dismantleUIViewController(_ controller:UIViewController,coordinator:Coordinator) {
        let session=coordinator.session
        DispatchQueue.global(qos:.userInitiated).async {session?.stopRunning()}
    }
    final class Coordinator:NSObject,AVCaptureMetadataOutputObjectsDelegate {
        let onCode:(String)->Void
        var session:AVCaptureSession?
        var didScan=false
        init(onCode:@escaping (String)->Void){self.onCode=onCode}
        func metadataOutput(_ output:AVCaptureMetadataOutput,
                            didOutput metadataObjects:[AVMetadataObject],from connection:AVCaptureConnection) {
            guard !didScan,let value=(metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else{return}
            didScan=true
            onCode(value)
        }
    }
}

struct ItamarScanTabView:View {
    @EnvironmentObject private var cloud:ItamarCloudService
    @State private var cameraAllowed=false
    @State private var cameraDenied=false
    @State private var manualCode=""
    @State private var route:ItamarDesktopPairRoute?
    @State private var notice=""
    var body:some View {
        NavigationStack {
            VStack(spacing:18) {
                Label("Scan to connect",systemImage:"qrcode.viewfinder")
                    .font(.title2.bold())
                Text("Scan a Cloud Climb or ItamarOS login QR. You must review and approve every login.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                if !cloud.isSignedIn {
                    ContentUnavailableView("Sign in required",systemImage:"person.crop.circle.badge.exclamationmark",
                        description:Text("Sign in to your ItamarOS account before approving another device."))
                } else if cameraAllowed {
                    ItamarQRReader { code in parse(code) }
                        .frame(height:290)
                        .clipShape(RoundedRectangle(cornerRadius:20))
                    Label("Point your camera at the QR code",systemImage:"camera.viewfinder")
                        .font(.caption)
                } else {
                    ContentUnavailableView(cameraDenied ? "Camera access required":"Camera not started",
                        systemImage:"camera",description:Text("Allow camera access to scan a login QR."))
                    Button("Enable camera") {requestCamera()}
                        .buttonStyle(.borderedProminent)
                }
                HStack {
                    TextField("Or paste a login link",text:$manualCode)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    Button("Continue"){parse(manualCode)}
                        .disabled(!cloud.isSignedIn || manualCode.isEmpty)
                }
                if !notice.isEmpty {Text(notice).font(.footnote).foregroundStyle(.red)}
                Spacer()
            }
            .padding()
            .navigationTitle("Scan")
            .onAppear {requestCamera()}
            .sheet(item:$route) { item in
                ItamarDesktopPairApprovalView(request:item.request,isCloudClimb:item.isCloudClimb)
                    .environmentObject(cloud)
            }
        }
    }
    private func requestCamera() {
        guard cloud.isSignedIn else{return}
        switch AVCaptureDevice.authorizationStatus(for:.video) {
        case .authorized:cameraAllowed=true;cameraDenied=false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for:.video) { allowed in
                DispatchQueue.main.async {cameraAllowed=allowed;cameraDenied = !allowed}
            }
        default:cameraAllowed=false;cameraDenied=true
        }
    }
    private func parse(_ value:String) {
        guard cloud.isSignedIn else {notice=NSLocalizedString("Sign in first",comment:"Scanner sign-in error");return}
        guard let url=URL(string:value.trimmingCharacters(in:.whitespacesAndNewlines)),
              let components=URLComponents(url:url,resolvingAgainstBaseURL:false) else {
            notice=NSLocalizedString("Invalid QR link",comment:"Scanner invalid link");return
        }
        let host=url.host?.lowercased() ?? ""
        let isClimb=host=="cloud-climb"
        guard url.scheme?.lowercased()=="itamaros",
              isClimb || host=="desktop",
              let request=components.queryItems?.first(where:{$0.name=="request"})?.value,
              (24...40).contains(request.count),
              request.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber || $0=="_" || $0=="-")})
        else {notice=NSLocalizedString("This QR is not a supported ItamarOS login request",comment:"Scanner unsupported code");return}
        notice=""
        cameraAllowed=false
        route=ItamarDesktopPairRoute(request:request,isCloudClimb:isClimb)
    }
}

#endif
