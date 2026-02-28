import SwiftUI

struct LoadingView: View {

    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.ledgrPrimary.opacity(0.15), lineWidth: 4)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.ledgrPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .cardStyle(padding: 32, cornerRadius: 24)
        .onAppear { isAnimating = true }
    }

    @State private var isAnimating = false
}

#Preview {
    ZStack {
        Color.ledgrBackground.ignoresSafeArea()
        LoadingView("Analyzing receipt...")
    }
}
