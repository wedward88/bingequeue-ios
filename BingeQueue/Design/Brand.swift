import SwiftUI

enum Brand {
    // BingeQueue DaisyUI theme
    static let primary = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255) // #A78BFA
    static let primaryContent = Color(red: 26 / 255, green: 11 / 255, blue: 46 / 255) // #1A0B2E
    static let accent = Color(red: 192 / 255, green: 132 / 255, blue: 252 / 255) // #C084FC
    static let secondary = Color(red: 182 / 255, green: 168 / 255, blue: 201 / 255) // #B6A8C9
    static let neutral = Color(red: 12 / 255, green: 6 / 255, blue: 20 / 255) // #0C0614
    static let base100 = Color(red: 22 / 255, green: 14 / 255, blue: 34 / 255) // #160E22
    static let base200 = Color(red: 30 / 255, green: 21 / 255, blue: 48 / 255) // #1E1530
    static let base300 = Color(red: 47 / 255, green: 35 / 255, blue: 69 / 255) // #2F2345
    static let baseContent = Color(red: 240 / 255, green: 232 / 255, blue: 250 / 255) // #F0E8FA
    static let surface = Color(red: 30 / 255, green: 21 / 255, blue: 48 / 255) // #1e1530
    static let surfaceMuted = Color(red: 36 / 255, green: 26 / 255, blue: 58 / 255) // #241a3a
    static let success = Color(red: 52 / 255, green: 211 / 255, blue: 153 / 255)
    static let warning = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
    static let error = Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255)

    static let buttonCornerRadius: CGFloat = 4
    static let cardCornerRadius: CGFloat = 0
}

struct BrandBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 28 / 255, green: 18 / 255, blue: 48 / 255), // #1c1230
                Color(red: 24 / 255, green: 16 / 255, blue: 42 / 255), // #18102a
                Color(red: 18 / 255, green: 10 / 255, blue: 28 / 255), // #120a1c
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
