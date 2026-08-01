import GoogleSignInSwift
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthSession

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 28) {
                Spacer()

                VStack(alignment: .center, spacing: 20) {
                    BrandWordmark(fontSize: 44, weight: .medium, showUnderline: true)

                    Text("Stop juggling streaming apps.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Brand.baseContent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)

                    Text("Track what you pay for and find where to watch—without another forgotten subscription.")
                        .font(.body)
                        .foregroundStyle(Brand.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 14) {
                    if auth.isSigningIn {
                        ProgressView()
                            .tint(Brand.primary)
                    }

                    GoogleSignInButton(action: {
                        Task { await auth.signInWithGoogle() }
                    })
                    .frame(height: 48)
                    .disabled(auth.isSigningIn)

                    Button {
                        auth.continueAsGuest()
                    } label: {
                        Text("Continue without an account")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(Brand.baseContent)
                            .background(Brand.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Brand.buttonCornerRadius)
                                    .stroke(Brand.base300, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Brand.buttonCornerRadius))
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isSigningIn)

                    Text("Without an account, subscriptions and your watch list stay on this iPhone only — separate from any BingeQueue account.")
                        .font(.caption)
                        .foregroundStyle(Brand.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    if let errorMessage = auth.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Brand.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
