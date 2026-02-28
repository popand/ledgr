import Foundation

struct LineItem: Identifiable, Codable, Hashable {
    let id: UUID
    var itemDescription: String
    var amount: Double

    init(id: UUID = UUID(), itemDescription: String, amount: Double) {
        self.id = id
        self.itemDescription = itemDescription
        self.amount = amount
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case itemDescription = "description"
        case amount
    }
}
