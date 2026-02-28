import SwiftUI

struct ErrorView: View {

    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.ledgrError.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.ledgrError)
            }

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundStyle(Color.ledgrDark)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let retryAction {
                Button(action: retryAction) {
                    Text("Try Again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.ledgrPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(24)
        .cardStyle(padding: 24, cornerRadius: 24)
    }
}

#Preview {
    ZStack {
        Color.ledgrBackground.ignoresSafeArea()
        ErrorView(message: "Failed to upload receipt. Check your connection.") {
            print("retry")
        }
    }
}
