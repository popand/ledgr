import SwiftUI

struct CategoryBadgeView: View {

    let category: ExpenseCategory
    var style: BadgeStyle = .pill

    enum BadgeStyle {
        case pill
        case icon
    }

    var body: some View {
        switch style {
        case .pill:
            pillBadge
        case .icon:
            iconBadge
        }
    }

    private var pillBadge: some View {
        Text(category.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 44, height: 44)

            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
        }
    }

    var color: Color {
        switch category {
        case .foodAndDining: return .categoryFood
        case .travel: return .categoryTravel
        case .officeSupplies: return .categoryOffice
        case .entertainment: return .categoryEntertainment
        case .utilities: return .categoryUtilities
        case .health: return .categoryHealth
        case .shopping: return .categoryShopping
        case .other: return .categoryOther
        }
    }

    private var iconName: String {
        switch category {
        case .foodAndDining: return "fork.knife"
        case .travel: return "airplane"
        case .officeSupplies: return "paperclip"
        case .entertainment: return "film"
        case .utilities: return "bolt.fill"
        case .health: return "heart.fill"
        case .shopping: return "bag.fill"
        case .other: return "square.grid.2x2"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                CategoryBadgeView(category: cat, style: .icon)
            }
        }
        HStack {
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                CategoryBadgeView(category: cat)
            }
        }
    }
    .padding()
}
