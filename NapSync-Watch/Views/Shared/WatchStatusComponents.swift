import SwiftUI

struct StatusTile: View {
    let icon: String
    let title: String
    let value: String
    var tint: Color = .blue

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct MetricChip: View {
    let title: String
    let value: String
    var tint: Color = .blue

    var body: some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.2))
        )
    }
}

#Preview("StatusTile") {
    StatusTile(icon: "heart.fill", title: "Health", value: "Authorized", tint: .pink)
        .previewLayout(.sizeThatFits)
}

#Preview("MetricChip") {
    MetricChip(title: "Elapsed", value: "12:45", tint: .green)
        .previewLayout(.sizeThatFits)
}
