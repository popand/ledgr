import SwiftUI
import SwiftData

struct HistoryView: View {

    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showDateFilter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    totalCard
                    categoryFilters
                    if showDateFilter { dateFilterCard }
                    breakdownSection
                    transactionsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.ledgrBackground.ignoresSafeArea())
            .searchable(text: $viewModel.searchText, prompt: "Search merchants")
            .onAppear {
                viewModel.loadExpenses(modelContext: modelContext)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Analytics")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ledgrDark)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDateFilter.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.ledgrDark)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Total Card

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                periodTabs
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Spent this Month")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(viewModel.totalAmount, format: .currency(code: "USD"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if viewModel.filteredExpenses.count > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.bold))
                            Text("\(viewModel.filteredExpenses.count) receipts")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color.ledgrSuccess)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.ledgrGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var periodTabs: some View {
        HStack(spacing: 0) {
            ForEach(["Week", "Month", "Year", "All"], id: \.self) { period in
                Button {
                    // Period filter placeholder
                } label: {
                    Text(period)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(period == "Month" ? .white : .clear)
                        .foregroundStyle(period == "Month" ? Color.ledgrPrimary : .white.opacity(0.7))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Category Filters

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectedCategory = nil
                }

                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        title: cat.rawValue,
                        isSelected: viewModel.selectedCategory == cat
                    ) {
                        viewModel.selectedCategory = (viewModel.selectedCategory == cat) ? nil : cat
                    }
                }
            }
        }
    }

    // MARK: - Date Filter

    private var dateFilterCard: some View {
        VStack(spacing: 12) {
            DatePicker(
                "From",
                selection: Binding(
                    get: { viewModel.startDate ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())! },
                    set: { viewModel.startDate = $0 }
                ),
                displayedComponents: .date
            )
            .font(.subheadline)

            Divider()

            DatePicker(
                "To",
                selection: Binding(
                    get: { viewModel.endDate ?? Date() },
                    set: { viewModel.endDate = $0 }
                ),
                displayedComponents: .date
            )
            .font(.subheadline)

            Button("Clear Dates") {
                viewModel.startDate = nil
                viewModel.endDate = nil
                withAnimation { showDateFilter = false }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.ledgrPrimary)
        }
        .cardStyle()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breakdown")
                .font(.headline)
                .foregroundStyle(Color.ledgrDark)

            if viewModel.categoryTotals.isEmpty {
                Text("No data yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.ledgrSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .cardStyle()
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.categoryTotals, id: \.0) { category, total in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(CategoryBadgeView(category: category).color)
                                .frame(width: 10, height: 10)

                            Text(category.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(Color.ledgrDark)

                            Spacer()

                            Text(total, format: .currency(code: "USD"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.ledgrDark)

                            let percentage = viewModel.totalAmount > 0 ? Int((total / viewModel.totalAmount) * 100) : 0
                            Text("\(percentage)%")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.ledgrSecondaryText)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Transactions

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Transactions")
                    .font(.headline)
                    .foregroundStyle(Color.ledgrDark)

                Spacer()

                Text("Filter")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.ledgrPrimary)
            }

            if viewModel.filteredExpenses.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredExpenses.enumerated()), id: \.element.id) { index, expense in
                        ExpenseRowView(expense: expense)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteExpense(expense, modelContext: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                        if index < viewModel.filteredExpenses.count - 1 {
                            Divider()
                                .padding(.leading, 58)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(Color.ledgrSubtleText)

            Text("No expenses found")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.ledgrSecondaryText)

            Text("Scan a receipt to get started")
                .font(.caption)
                .foregroundStyle(Color.ledgrSubtleText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .cardStyle()
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.ledgrPrimary : Color.white)
                .foregroundStyle(isSelected ? .white : Color.ledgrSecondaryText)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(isSelected ? 0 : 0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: Expense.self, inMemory: true)
}
