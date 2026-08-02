import Foundation
import GoogleSignIn
import SwiftUI
import UIKit

enum AppSessionMode: Equatable {
    case signedOut
    case guest
    case authenticated
}

@MainActor
final class AuthSession: ObservableObject {
    private static let guestDefaultsKey = "bingequeue.isGuest"

    @Published private(set) var mode: AppSessionMode = .signedOut
    @Published private(set) var user: UserProfile?
    @Published private(set) var isRestoring = true
    @Published var errorMessage: String?
    @Published var isSigningIn = false

    private let api: APIClient

    var isActive: Bool {
        mode == .guest || mode == .authenticated
    }

    var isGuest: Bool {
        mode == .guest
    }

    var isAuthenticated: Bool {
        mode == .authenticated
    }

    init(api: APIClient = .shared) {
        self.api = api
        api.onUnauthorized = { [weak self] in
            Task { @MainActor in
                // Only kick out cloud sessions; guest mode has no token.
                guard self?.mode == .authenticated else { return }
                self?.signOut(clearGoogle: false)
            }
        }
        restore()
    }

    func restore() {
        if let token = KeychainStore.loadToken(), !token.isEmpty {
            user = KeychainStore.loadUser()
            mode = .authenticated
            UserDefaults.standard.set(false, forKey: Self.guestDefaultsKey)
            UserDefaults.standard.removeObject(forKey: "servicecycle.isGuest")
        } else if UserDefaults.standard.bool(forKey: Self.guestDefaultsKey)
            || UserDefaults.standard.bool(forKey: "servicecycle.isGuest")
        {
            mode = .guest
            user = nil
            UserDefaults.standard.set(true, forKey: Self.guestDefaultsKey)
            UserDefaults.standard.removeObject(forKey: "servicecycle.isGuest")
        } else {
            mode = .signedOut
            user = nil
        }
        isRestoring = false
    }

    func continueAsGuest() {
        errorMessage = nil
        KeychainStore.clear()
        GIDSignIn.sharedInstance.signOut()
        UserDefaults.standard.set(true, forKey: Self.guestDefaultsKey)
        user = nil
        mode = .guest
    }

    func signInWithGoogle() async {
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }

        guard
            let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
        else {
            errorMessage = "Unable to present Google Sign-In."
            return
        }

        do {
            let config = GIDConfiguration(
                clientID: AppConfig.googleClientID,
                serverClientID: AppConfig.googleServerClientID
            )
            GIDSignIn.sharedInstance.configuration = config
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google did not return an ID token."
                return
            }

            let auth = try await api.exchangeGoogleToken(idToken)
            try KeychainStore.saveToken(auth.token)
            try KeychainStore.saveUser(auth.user)
            // Leave guest on-device library intact; account data comes from the API only.
            UserDefaults.standard.set(false, forKey: Self.guestDefaultsKey)
            user = auth.user
            mode = .authenticated
        } catch {
            // Prefer the API / SDK message; fall back to a Debug-specific hint.
            let message = UserFacingError.message(from: error)
                ?? "Google Sign-In failed."
            #if DEBUG
            if message.localizedCaseInsensitiveContains("reach")
                || message.localizedCaseInsensitiveContains("connect")
                || message.localizedCaseInsensitiveContains("offline")
            {
                errorMessage =
                    "\(message) In Debug, the app calls \(AppConfig.apiBaseURL.absoluteString) — run the web app locally and use the Simulator (not a physical phone)."
            } else {
                errorMessage = message
            }
            #else
            errorMessage = message
            #endif
        }
    }

    /// Returns to the welcome screen.
    /// Guest on-device library is preserved; account data remains on the server.
    func signOut(clearGoogle: Bool = true) {
        KeychainStore.clear()
        UserDefaults.standard.set(false, forKey: Self.guestDefaultsKey)
        user = nil
        mode = .signedOut
        if clearGoogle {
            GIDSignIn.sharedInstance.signOut()
        }
    }
}
