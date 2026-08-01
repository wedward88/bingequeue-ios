import GoogleSignIn
import SwiftUI

@main
struct BingeQueueApp: App {
    @StateObject private var auth = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
