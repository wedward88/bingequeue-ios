import SwiftUI

/// BingeQueue mark: Q with a play triangle inside.
/// Geometry mirrors `bingequeue/app/components/BrandMark.tsx`.
struct BrandMarkView: View {
    enum Variant {
        /// Full 64×64 artboard.
        case standard
        /// Tighter crop for use as the Q in “BingeQueue”.
        case wordmark
    }

    var variant: Variant = .standard
    var color: Color = Brand.primary

    var body: some View {
        Canvas { context, size in
            let viewBox: CGRect
            let strokeWidth: CGFloat
            let triangle: [CGPoint]

            switch variant {
            case .standard:
                viewBox = CGRect(x: 0, y: 0, width: 64, height: 64)
                strokeWidth = 5
                triangle = [
                    CGPoint(x: 23.5, y: 20.5),
                    CGPoint(x: 23.5, y: 37.5),
                    CGPoint(x: 38.5, y: 29),
                ]
            case .wordmark:
                viewBox = CGRect(x: 8, y: 8, width: 46, height: 46)
                strokeWidth = 5.5
                triangle = [
                    CGPoint(x: 25, y: 22),
                    CGPoint(x: 25, y: 36),
                    CGPoint(x: 36.5, y: 29),
                ]
            }

            let scale = min(size.width / viewBox.width, size.height / viewBox.height)
            let drawn = CGSize(width: viewBox.width * scale, height: viewBox.height * scale)
            let origin = CGPoint(
                x: (size.width - drawn.width) / 2,
                y: (size.height - drawn.height) / 2
            )

            func map(_ point: CGPoint) -> CGPoint {
                CGPoint(
                    x: origin.x + (point.x - viewBox.minX) * scale,
                    y: origin.y + (point.y - viewBox.minY) * scale
                )
            }

            var circle = Path()
            circle.addEllipse(
                in: CGRect(
                    x: origin.x + (29 - 18 - viewBox.minX) * scale,
                    y: origin.y + (29 - 18 - viewBox.minY) * scale,
                    width: 36 * scale,
                    height: 36 * scale
                )
            )
            context.stroke(
                circle,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth * scale, lineCap: .round)
            )

            var stem = Path()
            stem.move(to: map(CGPoint(x: 41.5, y: 41.5)))
            stem.addLine(to: map(CGPoint(x: 52, y: 52)))
            context.stroke(
                stem,
                with: .color(color),
                style: StrokeStyle(lineWidth: strokeWidth * scale, lineCap: .round)
            )

            var play = Path()
            play.move(to: map(triangle[0]))
            play.addLine(to: map(triangle[1]))
            play.addLine(to: map(triangle[2]))
            play.closeSubpath()
            context.fill(play, with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

/// Soft purple fade line under the landing wordmark.
/// Mirrors `.brand-underline` in `bingequeue/app/globals.css` (draw-in + glisten).
struct BrandUnderline: View {
    var animate: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrawn = false
    @State private var glisten = false

    private var baseFill: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Brand.primary.opacity(0.28), location: 0.14),
                .init(color: Brand.primary.opacity(0.65), location: 0.50),
                .init(color: Brand.primary.opacity(0.28), location: 0.86),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// `color-mix(in srgb, #a78bfa 55%, white)`
    private var glistenHighlight: Color {
        Color(
            red: (167 * 0.55 + 255 * 0.45) / 255,
            green: (139 * 0.55 + 255 * 0.45) / 255,
            blue: (250 * 0.55 + 255 * 0.45) / 255
        )
    }

    var body: some View {
        Capsule()
            .fill(baseFill)
            .overlay {
                if animate && !reduceMotion {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        let height = proxy.size.height
                        Capsule()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .clear, location: 0.38),
                                        .init(color: glistenHighlight.opacity(0.9), location: 0.50),
                                        .init(color: .clear, location: 0.62),
                                        .init(color: .clear, location: 1),
                                    ],
                                    startPoint: UnitPoint(x: 0.05, y: 0.85),
                                    endPoint: UnitPoint(x: 0.95, y: 0.15)
                                )
                            )
                            .frame(width: width * 2.4, height: height)
                            .offset(x: glisten ? -width * 0.55 : width * 0.55)
                            .opacity(glisten ? 1 : 0.35)
                            .frame(width: width, height: height, alignment: .center)
                    }
                    .clipShape(Capsule())
                    .allowsHitTesting(false)
                }
            }
            .scaleEffect(
                x: isDrawn ? 1 : 0,
                y: 1,
                anchor: UnitPoint(x: 0.35, y: 0.5)
            )
            .opacity(isDrawn ? 1 : 0)
            .onAppear(perform: startAnimations)
    }

    private func startAnimations() {
        guard animate else {
            isDrawn = true
            return
        }

        if reduceMotion {
            isDrawn = true
            return
        }

        withAnimation(.easeOut(duration: 0.7).delay(0.18)) {
            isDrawn = true
        }

        // Web: 3.6s ease-in-out infinite, delay 0.85s (autoreverse ≈ full cycle).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glisten = true
            }
        }
    }
}

/// “BingeQueue” with the play-Q mark standing in for the letter Q.
/// Mirrors `bingequeue/app/components/BrandWordmark.tsx`.
struct BrandWordmark: View {
    var fontSize: CGFloat = 17
    var weight: Font.Weight = .medium
    var color: Color = Brand.baseContent
    var markColor: Color = Brand.primary
    /// Landing-style gradient underline (nav titles usually omit this).
    var showUnderline: Bool = false

    private var markSide: CGFloat { fontSize * 0.95 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Binge")
                BrandMarkView(variant: .wordmark, color: markColor)
                    .frame(width: markSide, height: markSide)
                    // Web: ml-[0.05em] -mr-[0.06em] translate-y-[0.18em]
                    .padding(.leading, fontSize * 0.05)
                    .padding(.trailing, -fontSize * 0.06)
                    .offset(y: fontSize * 0.18)
                Text("ueue")
            }
            .font(.system(size: fontSize, weight: weight, design: .default))
            .tracking(-0.6)
            .foregroundStyle(color)
            // Room for the downward-shifted Q so it isn’t clipped.
            .padding(.bottom, showUnderline ? 0 : fontSize * 0.12)

            if showUnderline {
                BrandUnderline(animate: true)
                    .frame(height: max(2, fontSize * 0.09))
                    .padding(.top, fontSize * 0.28)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BingeQueue")
    }
}
