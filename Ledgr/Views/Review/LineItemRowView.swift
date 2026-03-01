import SwiftUI

struct LineItemRowView: View {

    @Binding var item: LineItem
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(Color.ledgrSubtleText)

            TextField("Description", text: $item.itemDescription)
                .font(.subheadline)
                .foregroundStyle(Color.ledgrDark)

            TextField("0.00", value: $item.amount, format: .number)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ledgrDark)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 80)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.ledgrSubtleText)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.ledgrBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    LineItemRowView(
        item: .constant(LineItem(itemDescription: "Iced Latte", amount: 5.50)),
        onDelete: {}
    )
    .padding()
}
