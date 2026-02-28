import Foundation

enum ExpenseCategory: String, Codable, CaseIterable {
    case foodAndDining = "Food & Dining"
    case travel = "Travel"
    case officeSupplies = "Office Supplies"
    case entertainment = "Entertainment"
    case utilities = "Utilities"
    case health = "Health"
    case shopping = "Shopping"
    case other = "Other"
}
