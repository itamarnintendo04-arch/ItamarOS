#if os(iOS)
import SwiftUI
import AuthenticationServices

// System-managed Apple Account authorization. No Apple passwords or private
// developer keys are collected, uploaded or stored by ItamarOS.
struct AppleAccountSignInView: View {
    @State private var authorizationComplete = false
    @State private var message = "Optional account sign-in. This does not sign or install IPA files."

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if authorizationComplete {
                HStack {
                    Label("Apple authorization completed", systemImage: "checkmark.shield")
                        .font(.subheadline)
                    Button("Clear") {
                        authorizationComplete = false
                        message = "Local authorization display cleared."
                    }
                    .font(.caption)
                }
            } else {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = []
                }, onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if authorization.credential is ASAuthorizationAppleIDCredential {
                            authorizationComplete = true
                            message = "Apple confirmed this sign-in. No server account has been created; IPA installation still requires a separate valid signing method."
                        } else {
                            message = "Unsupported Apple authorization credential."
                        }
                    case .failure(let error):
                        message = "Apple sign-in unavailable: \(error.localizedDescription). An enabled Sign in with Apple capability and valid code signing are required."
                    }
                })
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(width: 180, height: 44)
            }
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
