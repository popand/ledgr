import SwiftUI

struct AllInsightsView: View {

    let insights: [Insight]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if insights.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(insights) { insight in
                            insightCard(insight)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .background(Color.ledgrBackground.ignoresSafeArea())
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.ledgrPrimary)
                }
            }
        }
    }

    private func insightCard(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(insight.iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: insight.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(insight.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ledgrDark)

                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(Color.ledgrSecondaryText)
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Color.ledgrSubtleText)

            Text("No insights yet")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ledgrSecondaryText)

            Text("Add some expenses to get AI-powered insights")
                .font(.caption)
                .foregroundStyle(Color.ledgrSubtleText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    AllInsightsView(insights: [
        Insight(title: "Spending is down", description: "Your expenses decreased by 14% compared to last month.", icon: "arrow.down.circle.fill", iconColorName: "success"),
        Insight(title: "Top Category", description: "Food & Dining accounts for 45% of spending.", icon: "lightbulb.fill", iconColorName: "warning")
    ])
}
